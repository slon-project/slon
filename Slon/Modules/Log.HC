#define LOG_DB 100
#define LOG_HTTPD 101

U0 @slon_log(I64 module, U8* fmt, ...)
{
    CDateStruct ds;
    Date2Struct(&ds, Now);
    AdamLog("[%02d:%02d]", ds.hour, ds.min);
    switch (module) {
    case LOG_DB:
        AdamLog("[   slon/db] ");
        break;
    case LOG_HTTPD:
        AdamLog("[slon/httpd] ");
        break;
    default:
        AdamLog("[ slon/misc] ");
        break;
    }
    AdamLog(fmt, argc, argv);
    AdamLog("\n");
}
