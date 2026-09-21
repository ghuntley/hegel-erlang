use hegel_c::{
    HegelContext, HegelRun, HegelSettings, HegelTestCase, hegel_result_t, hegel_run_status_t,
};
use rustler::{
    Atom, Binary, Encoder, Env, Error, NewBinary, NifResult, Resource, ResourceArc, Term,
};
use std::ffi::{CStr, CString};
use std::ptr;
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok, error, stop, done, passed, failed, failed_nondeterministic,
        valid, invalid, overrun, interesting
    }
}

#[derive(Copy, Clone)]
struct RunPtr(*mut HegelRun);
unsafe impl Send for RunPtr {}
unsafe impl Sync for RunPtr {}

struct RunResource(Mutex<RunPtr>);
unsafe impl Send for RunResource {}
unsafe impl Sync for RunResource {}
#[rustler::resource_impl]
impl Resource for RunResource {}

impl Drop for RunResource {
    fn drop(&mut self) {
        if let Ok(guard) = self.0.lock() {
            let _ = with_ctx(|ctx| unsafe { hegel_c::hegel_run_free(ctx, guard.0) });
        }
    }
}

#[derive(Copy, Clone)]
struct CasePtr(*mut HegelTestCase);
unsafe impl Send for CasePtr {}
unsafe impl Sync for CasePtr {}

struct CaseResource(Mutex<CasePtr>);
unsafe impl Send for CaseResource {}
unsafe impl Sync for CaseResource {}
#[rustler::resource_impl]
impl Resource for CaseResource {}

impl Drop for CaseResource {
    fn drop(&mut self) {
        if let Ok(guard) = self.0.lock() {
            let _ = with_ctx(|ctx| unsafe { hegel_c::hegel_test_case_free(ctx, guard.0) });
        }
    }
}

#[derive(Copy, Clone)]
struct PrinterPtr(*mut hegel_c::HegelPrinter);
unsafe impl Send for PrinterPtr {}
unsafe impl Sync for PrinterPtr {}
struct PrinterResource(Mutex<PrinterPtr>);
unsafe impl Send for PrinterResource {}
unsafe impl Sync for PrinterResource {}
#[rustler::resource_impl]
impl Resource for PrinterResource {}
impl Drop for PrinterResource {
    fn drop(&mut self) {
        if let Ok(guard) = self.0.lock() {
            let _ = with_ctx(|ctx| unsafe { hegel_c::hegel_printer_free(ctx, guard.0) });
        }
    }
}

struct Context(*mut HegelContext);
impl Context {
    fn new() -> Self {
        Self(hegel_c::hegel_context_new())
    }
    fn error(&self) -> String {
        let value = unsafe { hegel_c::hegel_context_last_error(self.0) };
        if value.is_null() {
            "libhegel error".into()
        } else {
            unsafe { CStr::from_ptr(value) }
                .to_string_lossy()
                .into_owned()
        }
    }
}
impl Drop for Context {
    fn drop(&mut self) {
        unsafe {
            let _ = hegel_c::hegel_context_free(self.0);
        }
    }
}

fn with_ctx<T>(f: impl FnOnce(*mut HegelContext) -> T) -> T {
    let ctx = Context::new();
    f(ctx.0)
}

fn c_string(value: &str) -> NifResult<CString> {
    CString::new(value).map_err(|_| Error::BadArg)
}

fn call(ctx: &Context, result: hegel_result_t) -> Result<(), String> {
    match result {
        hegel_result_t::HEGEL_OK => Ok(()),
        hegel_result_t::HEGEL_E_STOP_TEST => Err("$stop".into()),
        _ => Err(ctx.error()),
    }
}

unsafe fn settings(
    ctx: &Context,
    profile: &str,
    test_cases: u64,
    seed: Option<u64>,
    derandomize: bool,
    multiple: bool,
    statistics: bool,
    print_blob: bool,
    database: &str,
) -> Result<*mut HegelSettings, String> {
    let mut out = ptr::null_mut();
    let profile = CString::new(profile).map_err(|_| "profile contains NUL".to_string())?;
    call(ctx, unsafe {
        hegel_c::hegel_settings_new_for_profile(ctx.0, profile.as_ptr(), &mut out)
    })?;
    let configured = (|| {
        call(ctx, unsafe {
            hegel_c::hegel_settings_set_test_cases(ctx.0, out, test_cases)
        })?;
        call(ctx, unsafe {
            hegel_c::hegel_settings_set_seed(ctx.0, out, seed.unwrap_or(0), seed.is_some())
        })?;
        call(ctx, unsafe {
            hegel_c::hegel_settings_set_derandomize(ctx.0, out, derandomize)
        })?;
        call(ctx, unsafe {
            hegel_c::hegel_settings_set_report_multiple_failures(ctx.0, out, multiple)
        })?;
        call(ctx, unsafe {
            hegel_c::hegel_settings_set_show_statistics(ctx.0, out, statistics)
        })?;
        call(ctx, unsafe {
            hegel_c::hegel_settings_set_print_blob(ctx.0, out, print_blob)
        })
        .and_then(|_| {
            if database == "$default" {
                call(ctx, unsafe {
                    hegel_c::hegel_settings_set_database(ctx.0, out, ptr::null())
                })
            } else {
                let value =
                    CString::new(database).map_err(|_| "database path contains NUL".to_string())?;
                call(ctx, unsafe {
                    hegel_c::hegel_settings_set_database(ctx.0, out, value.as_ptr())
                })
            }
        })
    })();
    if configured.is_err() {
        unsafe {
            let _ = hegel_c::hegel_settings_free(ctx.0, out);
        }
    }
    configured.map(|_| out)
}

fn error_tuple<'a>(env: Env<'a>, message: impl Encoder) -> Term<'a> {
    (atoms::error(), message).encode(env)
}

#[rustler::nif]
fn version() -> NifResult<String> {
    let ctx = Context::new();
    let mut out = ptr::null();
    call(&ctx, unsafe { hegel_c::hegel_version(ctx.0, &mut out) }).map_err(|_| Error::BadArg)?;
    Ok(unsafe { CStr::from_ptr(out) }
        .to_string_lossy()
        .into_owned())
}

#[rustler::nif(schedule = "DirtyCpu")]
fn run_start<'a>(
    env: Env<'a>,
    profile: Binary,
    test_cases: u64,
    seed: Option<u64>,
    derandomize: bool,
    multiple: bool,
    statistics: bool,
    print_blob: bool,
    database: Binary,
) -> Term<'a> {
    let Ok(profile) = std::str::from_utf8(profile.as_slice()) else {
        return error_tuple(env, "invalid profile");
    };
    let Ok(database) = std::str::from_utf8(database.as_slice()) else {
        return error_tuple(env, "invalid database path");
    };
    let ctx = Context::new();
    let configured = unsafe {
        settings(
            &ctx,
            profile,
            test_cases,
            seed,
            derandomize,
            multiple,
            statistics,
            print_blob,
            database,
        )
    };
    let Ok(configured) = configured else {
        return error_tuple(env, configured.unwrap_err());
    };
    let mut run = ptr::null_mut();
    let result =
        unsafe { hegel_c::hegel_run_start(ctx.0, configured, None, ptr::null_mut(), &mut run) };
    unsafe {
        let _ = hegel_c::hegel_settings_free(ctx.0, configured);
    }
    match call(&ctx, result) {
        Ok(()) => (
            atoms::ok(),
            ResourceArc::new(RunResource(Mutex::new(RunPtr(run)))),
        )
            .encode(env),
        Err(message) => error_tuple(env, message),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn run_next<'a>(env: Env<'a>, run: ResourceArc<RunResource>) -> Term<'a> {
    let guard = match run.0.lock() {
        Ok(g) => g,
        Err(_) => return error_tuple(env, "run lock poisoned"),
    };
    let ctx = Context::new();
    let mut tc = ptr::null_mut();
    match call(&ctx, unsafe {
        hegel_c::hegel_next_test_case(ctx.0, guard.0, &mut tc)
    }) {
        Ok(()) if tc.is_null() => atoms::done().encode(env),
        Ok(()) => (
            atoms::ok(),
            ResourceArc::new(CaseResource(Mutex::new(CasePtr(tc)))),
        )
            .encode(env),
        Err(message) => error_tuple(env, message),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn run_result<'a>(env: Env<'a>, run: ResourceArc<RunResource>) -> Term<'a> {
    let guard = match run.0.lock() {
        Ok(g) => g,
        Err(_) => return error_tuple(env, "run lock poisoned"),
    };
    let ctx = Context::new();
    let mut result = ptr::null_mut();
    if let Err(message) = call(&ctx, unsafe {
        hegel_c::hegel_run_result(ctx.0, guard.0, &mut result)
    }) {
        return error_tuple(env, message);
    }
    let term = unsafe { encode_run_result(env, &ctx, result) };
    unsafe {
        let _ = hegel_c::hegel_run_result_free(ctx.0, result);
    }
    term
}

unsafe fn encode_run_result<'a>(
    env: Env<'a>,
    ctx: &Context,
    result: *mut hegel_c::HegelRunResult,
) -> Term<'a> {
    let mut status = hegel_run_status_t::HEGEL_RUN_STATUS_ERROR;
    if let Err(message) = call(ctx, unsafe {
        hegel_c::hegel_run_result_status(ctx.0, result, &mut status)
    }) {
        return error_tuple(env, message);
    }
    match status {
        hegel_run_status_t::HEGEL_RUN_STATUS_PASSED => {
            (atoms::passed(), Vec::<Term>::new()).encode(env)
        }
        hegel_run_status_t::HEGEL_RUN_STATUS_ERROR => {
            let mut raw = ptr::null();
            unsafe {
                let _ = hegel_c::hegel_run_result_error(ctx.0, result, &mut raw);
            }
            let message = if raw.is_null() {
                "unknown run error".into()
            } else {
                unsafe { CStr::from_ptr(raw) }
                    .to_string_lossy()
                    .into_owned()
            };
            (atoms::error(), message).encode(env)
        }
        status @ (hegel_run_status_t::HEGEL_RUN_STATUS_FAILED
        | hegel_run_status_t::HEGEL_RUN_STATUS_FAILED_NONDETERMINISTIC) => {
            let mut count = 0;
            unsafe {
                let _ = hegel_c::hegel_run_result_failure_count(ctx.0, result, &mut count);
            }
            let mut failures = Vec::with_capacity(count);
            for index in 0..count {
                let mut failure = ptr::null_mut();
                unsafe {
                    let _ = hegel_c::hegel_run_result_failure(ctx.0, result, index, &mut failure);
                }
                let mut origin = ptr::null();
                let mut blob = ptr::null();
                unsafe {
                    let _ = hegel_c::hegel_failure_origin(ctx.0, failure, &mut origin);
                    let _ = hegel_c::hegel_failure_reproduction_blob(ctx.0, failure, &mut blob);
                }
                let origin = if origin.is_null() {
                    String::new()
                } else {
                    unsafe { CStr::from_ptr(origin) }
                        .to_string_lossy()
                        .into_owned()
                };
                let blob = if blob.is_null() {
                    String::new()
                } else {
                    unsafe { CStr::from_ptr(blob) }
                        .to_string_lossy()
                        .into_owned()
                };
                let map = rustler::types::map::map_new(env);
                let map = map
                    .map_put(Atom::from_str(env, "origin").unwrap(), origin)
                    .unwrap();
                let map = map
                    .map_put(Atom::from_str(env, "blob").unwrap(), blob)
                    .unwrap();
                failures.push(map);
                unsafe {
                    let _ = hegel_c::hegel_failure_free(ctx.0, failure);
                }
            }
            let atom = if status == hegel_run_status_t::HEGEL_RUN_STATUS_FAILED {
                atoms::failed()
            } else {
                atoms::failed_nondeterministic()
            };
            (atom, failures).encode(env)
        }
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn case_from_blob<'a>(
    env: Env<'a>,
    profile: Binary,
    blob: Binary,
    test_cases: u64,
    seed: Option<u64>,
    derandomize: bool,
    statistics: bool,
    print_blob: bool,
    database: Binary,
) -> Term<'a> {
    let Ok(profile) = std::str::from_utf8(profile.as_slice()) else {
        return error_tuple(env, "invalid profile");
    };
    let Ok(blob) = std::str::from_utf8(blob.as_slice()) else {
        return error_tuple(env, "invalid blob");
    };
    let Ok(database) = std::str::from_utf8(database.as_slice()) else {
        return error_tuple(env, "invalid database path");
    };
    let Ok(blob) = c_string(blob) else {
        return error_tuple(env, "invalid blob");
    };
    let ctx = Context::new();
    let configured = unsafe {
        settings(
            &ctx,
            profile,
            test_cases,
            seed,
            derandomize,
            false,
            statistics,
            print_blob,
            database,
        )
    };
    let Ok(configured) = configured else {
        return error_tuple(env, configured.unwrap_err());
    };
    let mut tc = ptr::null_mut();
    let result = unsafe {
        hegel_c::hegel_test_case_from_blob(
            ctx.0,
            configured,
            blob.as_ptr(),
            None,
            ptr::null_mut(),
            &mut tc,
        )
    };
    unsafe {
        let _ = hegel_c::hegel_settings_free(ctx.0, configured);
    }
    match call(&ctx, result) {
        Ok(()) => (
            atoms::ok(),
            ResourceArc::new(CaseResource(Mutex::new(CasePtr(tc)))),
        )
            .encode(env),
        Err(message) => error_tuple(env, message),
    }
}

#[rustler::nif]
fn complete<'a>(
    env: Env<'a>,
    tc: ResourceArc<CaseResource>,
    status: Atom,
    origin: Binary,
) -> Term<'a> {
    let status = if status == atoms::valid() {
        0
    } else if status == atoms::invalid() {
        1
    } else if status == atoms::overrun() {
        2
    } else if status == atoms::interesting() {
        3
    } else {
        return error_tuple(env, "invalid status");
    };
    let origin = match std::str::from_utf8(origin.as_slice())
        .ok()
        .and_then(|s| CString::new(s).ok())
    {
        Some(s) => s,
        None => return error_tuple(env, "invalid origin"),
    };
    with_case(
        env,
        &tc,
        |ctx, raw| {
            (
                unsafe {
                    hegel_c::hegel_mark_complete(
                        ctx.0,
                        raw,
                        status,
                        if status == 3 {
                            origin.as_ptr()
                        } else {
                            ptr::null()
                        },
                    )
                },
                (),
            )
        },
        |_| atoms::ok().encode(env),
    )
}

#[rustler::nif]
fn clone_case<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            let mut out = ptr::null_mut();
            let rc = unsafe { hegel_c::hegel_test_case_clone(ctx.0, raw, &mut out) };
            (rc, out)
        },
        |out| {
            (
                atoms::ok(),
                ResourceArc::new(CaseResource(Mutex::new(CasePtr(out)))),
            )
                .encode(env)
        },
    )
}

fn with_case<'a, T>(
    env: Env<'a>,
    tc: &ResourceArc<CaseResource>,
    f: impl FnOnce(&Context, *mut HegelTestCase) -> (hegel_result_t, T),
    ok: impl FnOnce(T) -> Term<'a>,
) -> Term<'a> {
    let guard = match tc.0.lock() {
        Ok(g) => g,
        Err(_) => return error_tuple(env, "case lock poisoned"),
    };
    let ctx = Context::new();
    let (rc, value) = f(&ctx, guard.0);
    match call(&ctx, rc) {
        Ok(()) => ok(value),
        Err(s) if s == "$stop" => atoms::stop().encode(env),
        Err(s) => error_tuple(env, s),
    }
}

#[rustler::nif]
fn boolean<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, probability: f64) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            let mut out = false;
            let rc = unsafe {
                hegel_c::hegel_generate_boolean(ctx.0, raw, probability, false, false, &mut out)
            };
            (rc, out)
        },
        |v| (atoms::ok(), v).encode(env),
    )
}
#[rustler::nif]
fn integer<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, min: i64, max: i64) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            let mut out = 0;
            let rc = unsafe { hegel_c::hegel_generate_integer(ctx.0, raw, min, max, &mut out) };
            (rc, out)
        },
        |v| (atoms::ok(), v).encode(env),
    )
}
#[rustler::nif]
fn float<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, min: f64, max: f64) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            let mut out = 0.0;
            let rc = unsafe {
                hegel_c::hegel_generate_float(
                    ctx.0,
                    raw,
                    64,
                    min,
                    max,
                    false,
                    false,
                    false,
                    false,
                    f64::from_bits(1),
                    &mut out,
                )
            };
            (rc, out)
        },
        |v| (atoms::ok(), v).encode(env),
    )
}
#[rustler::nif]
fn bytes<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, min: u64, max: u64) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            let mut out = hegel_c::hegel_generate_bytes_result_t {
                data: ptr::null_mut(),
                len: 0,
            };
            let rc = unsafe { hegel_c::hegel_generate_bytes(ctx.0, raw, min, max, &mut out) };
            (rc, out)
        },
        |mut out| {
            let mut binary = NewBinary::new(env, out.len);
            if out.len > 0 {
                binary
                    .as_mut_slice()
                    .copy_from_slice(unsafe { std::slice::from_raw_parts(out.data, out.len) });
            }
            let _ =
                with_ctx(|ctx| unsafe { hegel_c::hegel_generate_bytes_result_free(ctx, &mut out) });
            let binary: Binary = binary.into();
            (atoms::ok(), binary).encode(env)
        },
    )
}
#[rustler::nif]
fn note<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, text: Binary) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            (
                unsafe {
                    hegel_c::hegel_note(ctx.0, raw, text.as_slice().as_ptr(), text.as_slice().len())
                },
                (),
            )
        },
        |_| atoms::ok().encode(env),
    )
}

#[rustler::nif]
fn event<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, label: Binary) -> Term<'a> {
    let Ok(label) = std::str::from_utf8(label.as_slice())
        .ok()
        .and_then(|s| CString::new(s).ok())
        .ok_or(())
    else {
        return error_tuple(env, "invalid event label");
    };
    with_case(
        env,
        &tc,
        |ctx, raw| {
            (
                unsafe { hegel_c::hegel_event(ctx.0, raw, label.as_ptr()) },
                (),
            )
        },
        |_| atoms::ok().encode(env),
    )
}

#[rustler::nif]
fn event_value<'a>(
    env: Env<'a>,
    tc: ResourceArc<CaseResource>,
    label: Binary,
    value: f64,
) -> Term<'a> {
    let Ok(label) = std::str::from_utf8(label.as_slice())
        .ok()
        .and_then(|s| CString::new(s).ok())
        .ok_or(())
    else {
        return error_tuple(env, "invalid event label");
    };
    with_case(
        env,
        &tc,
        |ctx, raw| {
            (
                unsafe { hegel_c::hegel_event_value(ctx.0, raw, value, label.as_ptr()) },
                (),
            )
        },
        |_| atoms::ok().encode(env),
    )
}

#[rustler::nif]
fn target<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>, label: Binary, value: f64) -> Term<'a> {
    let Ok(label) = std::str::from_utf8(label.as_slice())
        .ok()
        .and_then(|s| CString::new(s).ok())
        .ok_or(())
    else {
        return error_tuple(env, "invalid target label");
    };
    with_case(
        env,
        &tc,
        |ctx, raw| {
            (
                unsafe { hegel_c::hegel_target(ctx.0, raw, value, label.as_ptr()) },
                (),
            )
        },
        |_| atoms::ok().encode(env),
    )
}

#[rustler::nif]
fn open_printer<'a>(env: Env<'a>, tc: ResourceArc<CaseResource>) -> Term<'a> {
    with_case(
        env,
        &tc,
        |ctx, raw| {
            let mut printer = ptr::null_mut();
            let rc =
                unsafe { hegel_c::hegel_test_case_printer(ctx.0, raw, ptr::null(), &mut printer) };
            (rc, printer)
        },
        |printer| {
            (
                atoms::ok(),
                ResourceArc::new(PrinterResource(Mutex::new(PrinterPtr(printer)))),
            )
                .encode(env)
        },
    )
}

#[rustler::nif]
fn printer_output<'a>(env: Env<'a>, printer: ResourceArc<PrinterResource>) -> Term<'a> {
    let guard = match printer.0.lock() {
        Ok(guard) => guard,
        Err(_) => return error_tuple(env, "printer lock poisoned"),
    };
    let ctx = Context::new();
    let mut value = hegel_c::hegel_printer_value_result_t {
        data: ptr::null_mut(),
        len: 0,
    };
    if let Err(message) = call(&ctx, unsafe {
        hegel_c::hegel_printer_value(ctx.0, guard.0, &mut value)
    }) {
        return error_tuple(env, message);
    }
    let output = unsafe { std::slice::from_raw_parts(value.data.cast::<u8>(), value.len) }.to_vec();
    unsafe {
        let _ = hegel_c::hegel_printer_value_result_free(ctx.0, &mut value);
    }
    let mut binary = NewBinary::new(env, output.len());
    binary.as_mut_slice().copy_from_slice(&output);
    let binary: Binary = binary.into();
    (atoms::ok(), binary).encode(env)
}

rustler::init!("hegel_native");
