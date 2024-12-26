module sqlite;


const int SQLITE_OK =           0;   /* Successful result */
const int SQLITE_ERROR =        1;   /* Generic error */
const int SQLITE_INTERNAL =     2;   /* Internal logic error in SQLite */
const int SQLITE_PERM =         3;   /* Access permission denied */
const int SQLITE_ABORT =        4;   /* Callback routine requested an abort */
const int SQLITE_BUSY =         5;   /* The database file is locked */
const int SQLITE_LOCKED =       6;   /* A table in the database is locked */
const int SQLITE_NOMEM =        7;   /* A malloc() failed */
const int SQLITE_READONLY =     8;   /* Attempt to write a readonly database */
const int SQLITE_INTERRUPT =    9;   /* Operation terminated by sqlite3_interrupt()*/
const int SQLITE_IOERR =       10;   /* Some kind of disk I/O error occurred */
const int SQLITE_CORRUPT =     11;   /* The database disk image is malformed */
const int SQLITE_NOTFOUND =    12;   /* Unknown opcode in sqlite3_file_control() */
const int SQLITE_FULL =        13;   /* Insertion failed because database is full */
const int SQLITE_CANTOPEN =    14;   /* Unable to open the database file */
const int SQLITE_PROTOCOL =    15;   /* Database lock protocol error */
const int SQLITE_EMPTY =       16;   /* Internal use only */
const int SQLITE_SCHEMA =      17;   /* The database schema changed */
const int SQLITE_TOOBIG =      18;   /* String or BLOB exceeds size limit */
const int SQLITE_CONSTRAINT =  19;   /* Abort due to constraint violation */
const int SQLITE_MISMATCH =    20;   /* Data type mismatch */
const int SQLITE_MISUSE =      21;   /* Library used incorrectly */
const int SQLITE_NOLFS =       22;   /* Uses OS features not supported on host */
const int SQLITE_AUTH =        23;   /* Authorization denied */
const int SQLITE_FORMAT =      24;   /* Not used */
const int SQLITE_RANGE =       25;   /* 2nd parameter to sqlite3_bind out of range */
const int SQLITE_NOTADB =      26;   /* File opened that is not a database file */
const int SQLITE_NOTICE =      27;   /* Notifications from sqlite3_log() */
const int SQLITE_WARNING =     28;   /* Warnings from sqlite3_log() */
const int SQLITE_ROW =         100;  /* sqlite3_step() has another row ready */
const int SQLITE_DONE =        101;  /* sqlite3_step() has finished executing */

const int SQLITE_INTEGER  = 1;
const int SQLITE_FLOAT    = 2;
const int SQLITE_BLOB     = 4;
const int SQLITE_NULL     = 5;
const int SQLITE3_TEXT    = 3;

fn String status_string(CInt code) {
    switch (code) {
        case 0: return "SQLITE_OK"; 
        case 1: return "SQLITE_ERROR"; 
        case 2: return "SQLITE_INTERNAL"; 
        case 3: return "SQLITE_PERM"; 
        case 4: return "SQLITE_ABORT"; 
        case 5: return "SQLITE_BUSY"; 
        case 6: return "SQLITE_LOCKED"; 
        case 7: return "SQLITE_NOMEM"; 
        case 8: return "SQLITE_READONLY"; 
        case 9: return "SQLITE_INTERRUPT"; 
        case 10: return "SQLITE_IOERR"; 
        case 11: return "SQLITE_CORRUPT"; 
        case 12: return "SQLITE_NOTFOUND"; 
        case 13: return "SQLITE_FULL"; 
        case 14: return "SQLITE_CANTOPEN"; 
        case 15: return "SQLITE_PROTOCOL"; 
        case 16: return "SQLITE_EMPTY"; 
        case 17: return "SQLITE_SCHEMA"; 
        case 18: return "SQLITE_TOOBIG"; 
        case 19: return "SQLITE_CONSTRAINT"; 
        case 20: return "SQLITE_MISMATCH"; 
        case 21: return "SQLITE_MISUSE"; 
        case 22: return "SQLITE_NOLFS"; 
        case 23: return "SQLITE_AUTH"; 
        case 24: return "SQLITE_FORMAT"; 
        case 25: return "SQLITE_RANGE"; 
        case 26: return "SQLITE_NOTADB"; 
        case 27: return "SQLITE_NOTICE"; 
        case 28: return "SQLITE_WARNING"; 
        case 100: return "SQLITE_ROW";
        case 101: return "SQLITE_DONE";
        default: return "UNKNOWN";
    }
}

def SqliteHandle = void*;
def SqliteStmt = void*;
def ExecCallback = fn CInt (void* context, CInt num_columns, ZString* result, ZString* col_names);

extern fn CInt sqlite3_open(
  ZString       filename,       /* Database filename (UTF-8) */
  SqliteHandle* ppDb            /* OUT: SQLite db handle */
);

extern fn CInt sqlite3_close(SqliteHandle handle);

extern fn CInt sqlite3_exec(
  SqliteHandle handle,                       /* An open database */
  ZString sql,                               /* SQL to be evaluated */
  ExecCallback callback,                     /* Callback function */
  void * context,                            /* 1st argument to callback */
  ZString* errmsg                            /* Error msg written here */
);

extern fn CInt sqlite3_prepare_v2(
  SqliteHandle db,        /* Database handle */
  ZString zSql,           /* SQL statement, UTF-8 encoded */
  CInt nByte,             /* Maximum length of zSql in bytes. */
  SqliteStmt *ppStmt,     /* OUT: Statement handle */
  ZString* pzTail         /* OUT: Pointer to unused portion of zSql */
);

extern fn CInt sqlite3_step(SqliteStmt stmt);
extern fn CInt sqlite3_finalize(SqliteStmt pStmt);
extern fn CLong sqlite3_changes64(SqliteHandle handle);
extern fn CInt sqlite3_column_count(SqliteStmt pStmt);

extern fn void* sqlite3_column_blob(SqliteStmt stmt, int iCol);
extern fn double sqlite3_column_double(SqliteStmt stmt, int iCol);
extern fn CInt sqlite3_column_int(SqliteStmt stmt, int iCol);
extern fn CLong sqlite3_column_int64(SqliteStmt stmt, int iCol);
extern fn ZString sqlite3_column_text(SqliteStmt stmt, int iCol);
extern fn void* sqlite3_column_text16(SqliteStmt stmt, int iCol);
extern fn void* sqlite3_column_value(SqliteStmt stmt, int iCol);
extern fn CInt sqlite3_column_bytes(SqliteStmt stmt, int iCol);
extern fn CInt sqlite3_column_bytes16(SqliteStmt stmt, int iCol);
extern fn CInt sqlite3_column_type(SqliteStmt stmt, int iCol);

extern fn ZString sqlite3_errmsg(SqliteHandle handle);