#import "PythonBridge.h"
#include <Python.h>

@implementation PythonBridge

+ (BOOL)isAvailable {
    return YES;
}

+ (void)startWithPythonHome:(NSString *)pythonHome pythonPath:(NSString *)pythonPath {
    if (pythonHome.length > 0) {
        setenv("PYTHONHOME", pythonHome.UTF8String, 1);
    }
    if (pythonPath.length > 0) {
        setenv("PYTHONPATH", pythonPath.UTF8String, 1);
    }
    if (Py_IsInitialized() == 0) {
        Py_Initialize();
    }
}

+ (NSString *)base64:(NSString *)input {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

+ (NSDictionary *)runCode:(NSString *)code filename:(NSString *)filename {
    if (Py_IsInitialized() == 0) {
        return @{
            @"exitCode": @1,
            @"stdout": @"",
            @"stderr": @"Python interpreter is not initialized."
        };
    }

    NSString *encodedCode = [self base64:code ?: @""];
    NSString *encodedFilename = [self base64:filename ?: @"main.py"];

    NSString *wrapper = [NSString stringWithFormat:@
        "import base64, io, json, sys, traceback\n"
        "__ipyrunner_stdout = io.StringIO()\n"
        "__ipyrunner_stderr = io.StringIO()\n"
        "__ipyrunner_exit = 0\n"
        "__ipyrunner_code = base64.b64decode('%@').decode('utf-8')\n"
        "__ipyrunner_filename = base64.b64decode('%@').decode('utf-8')\n"
        "__ipyrunner_globals = {'__name__': '__main__', '__file__': __ipyrunner_filename}\n"
        "__ipyrunner_old_stdout, __ipyrunner_old_stderr = sys.stdout, sys.stderr\n"
        "try:\n"
        "    sys.stdout, sys.stderr = __ipyrunner_stdout, __ipyrunner_stderr\n"
        "    exec(compile(__ipyrunner_code, __ipyrunner_filename, 'exec'), __ipyrunner_globals, __ipyrunner_globals)\n"
        "except BaseException:\n"
        "    __ipyrunner_exit = 1\n"
        "    traceback.print_exc(file=__ipyrunner_stderr)\n"
        "finally:\n"
        "    sys.stdout, sys.stderr = __ipyrunner_old_stdout, __ipyrunner_old_stderr\n"
        "__ipyrunner_result__ = json.dumps({\n"
        "    'exitCode': __ipyrunner_exit,\n"
        "    'stdout': __ipyrunner_stdout.getvalue(),\n"
        "    'stderr': __ipyrunner_stderr.getvalue(),\n"
        "})\n",
        encodedCode,
        encodedFilename
    ];

    int rc = PyRun_SimpleString([wrapper UTF8String]);
    if (rc != 0) {
        return @{
            @"exitCode": @(rc),
            @"stdout": @"",
            @"stderr": @"Python bridge wrapper failed before user code completed."
        };
    }

    PyObject *mainModule = PyImport_AddModule("__main__");
    if (mainModule == NULL) {
        return @{
            @"exitCode": @1,
            @"stdout": @"",
            @"stderr": @"Could not access Python __main__ module."
        };
    }

    PyObject *resultObject = PyObject_GetAttrString(mainModule, "__ipyrunner_result__");
    if (resultObject == NULL) {
        PyErr_Clear();
        return @{
            @"exitCode": @1,
            @"stdout": @"",
            @"stderr": @"Python executed, but __ipyrunner_result__ was not found."
        };
    }

    const char *resultCString = PyUnicode_AsUTF8(resultObject);
    if (resultCString == NULL) {
        Py_DecRef(resultObject);
        PyErr_Clear();
        return @{
            @"exitCode": @1,
            @"stdout": @"",
            @"stderr": @"Python result was not UTF-8 text."
        };
    }

    NSString *jsonString = [NSString stringWithUTF8String:resultCString] ?: @"{}";
    Py_DecRef(resultObject);

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        return @{
            @"exitCode": @1,
            @"stdout": jsonString,
            @"stderr": [NSString stringWithFormat:@"Failed to parse Python bridge JSON: %@", error.localizedDescription ?: @"unknown"]
        };
    }

    return (NSDictionary *)parsed;
}

@end
