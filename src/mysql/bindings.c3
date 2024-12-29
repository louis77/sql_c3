module mysql8;

def Mysql = void*;
def MysqlRes = void*;
def MysqlRow = void**;
def MysqlStmt = void*;

const int MYSQL_NO_DATA = 100;

// enum_field_types
const int MYSQL_TYPE_DECIMAL = 0;
const int MYSQL_TYPE_TINY = 1;
const int MYSQL_TYPE_SHORT = 2;
const int MYSQL_TYPE_LONG = 3;
const int MYSQL_TYPE_FLOAT = 4;
const int MYSQL_TYPE_DOUBLE = 5;
const int MYSQL_TYPE_NULL = 6;
const int MYSQL_TYPE_TIMESTAMP = 7;
const int MYSQL_TYPE_LONGLONG = 8;
const int MYSQL_TYPE_INT24 = 9;
const int MYSQL_TYPE_DATE = 10;
const int MYSQL_TYPE_TIME = 11;
const int MYSQL_TYPE_DATETIME = 12;
const int MYSQL_TYPE_YEAR = 13;
const int MYSQL_TYPE_NEWDATE = 14; // Unused
const int MYSQL_TYPE_VARCHAR = 15;
const int MYSQL_TYPE_BIT = 16;
const int MYSQL_TYPE_TIMESTAMP2 = 17;
const int MYSQL_TYPE_DATETIME2 = 18; /**< Internal to MySQL. Not used in protocol */
const int MYSQL_TYPE_TIME2 = 19;  /**< Internal to MySQL. Not used in protocol */
const int MYSQL_TYPE_TYPED_ARRAY = 20; /**< Used for replication only */
const int MYSQL_TYPE_INVALID = 243;
const int MYSQL_TYPE_JSON = 245;
const int MYSQL_TYPE_NEWDECIMAL = 246;
const int MYSQL_TYPE_ENUM = 247;
const int MYSQL_TYPE_SET = 248;
const int MYSQL_TYPE_TINY_BLOB = 249;
const int MYSQL_TYPE_MEDIUM_BLOB = 250;
const int MYSQL_TYPE_LONG_BLOB = 251;
const int MYSQL_TYPE_BLOB = 252;
const int MYSQL_TYPE_VAR_STRING = 253;
const int MYSQL_TYPE_STRING = 254;
const int MYSQL_TYPE_GEOMETRY = 255;

enum MysqlOption : CInt {
  MYSQL_OPT_CONNECT_TIMEOUT,
  MYSQL_OPT_COMPRESS,
  MYSQL_OPT_NAMED_PIPE,
  MYSQL_INIT_COMMAND,
  MYSQL_READ_DEFAULT_FILE,
  MYSQL_READ_DEFAULT_GROUP,
  MYSQL_SET_CHARSET_DIR,
  MYSQL_SET_CHARSET_NAME,
  MYSQL_OPT_LOCAL_INFILE,
  MYSQL_OPT_PROTOCOL,
  MYSQL_SHARED_MEMORY_BASE_NAME,
  MYSQL_OPT_READ_TIMEOUT,
  MYSQL_OPT_WRITE_TIMEOUT,
  MYSQL_OPT_USE_RESULT,
  MYSQL_REPORT_DATA_TRUNCATION,
  MYSQL_OPT_RECONNECT,
  MYSQL_PLUGIN_DIR,
  MYSQL_DEFAULT_AUTH,
  MYSQL_OPT_BIND,
  MYSQL_OPT_SSL_KEY,
  MYSQL_OPT_SSL_CERT,
  MYSQL_OPT_SSL_CA,
  MYSQL_OPT_SSL_CAPATH,
  MYSQL_OPT_SSL_CIPHER,
  MYSQL_OPT_SSL_CRL,
  MYSQL_OPT_SSL_CRLPATH,
  MYSQL_OPT_CONNECT_ATTR_RESET,
  MYSQL_OPT_CONNECT_ATTR_ADD,
  MYSQL_OPT_CONNECT_ATTR_DELETE,
  MYSQL_SERVER_PUBLIC_KEY,
  MYSQL_ENABLE_CLEARTEXT_PLUGIN,
  MYSQL_OPT_CAN_HANDLE_EXPIRED_PASSWORDS,
  MYSQL_OPT_MAX_ALLOWED_PACKET,
  MYSQL_OPT_NET_BUFFER_LENGTH,
  MYSQL_OPT_TLS_VERSION,
  MYSQL_OPT_SSL_MODE,
  MYSQL_OPT_GET_SERVER_PUBLIC_KEY,
  MYSQL_OPT_RETRY_COUNT,
  MYSQL_OPT_OPTIONAL_RESULTSET_METADATA,
  MYSQL_OPT_SSL_FIPS_MODE,
  MYSQL_OPT_TLS_CIPHERSUITES,
  MYSQL_OPT_COMPRESSION_ALGORITHMS,
  MYSQL_OPT_ZSTD_COMPRESSION_LEVEL,
  MYSQL_OPT_LOAD_DATA_LOCAL_DIR,
  MYSQL_OPT_USER_PASSWORD,
  MYSQL_OPT_SSL_SESSION_DATA,
  MYSQL_OPT_TLS_SNI_SERVERNAME
}

enum Autocommit : CInt {
    AUTOCOMMIT_OFF,
    AUTOCOMMIT_ON
}

extern fn CULong        mysql_affected_rows(Mysql mysql);
extern fn bool          mysql_autocommit(Mysql mysql, Autocommit mode);
extern fn void          mysql_close(Mysql mysql);
extern fn bool          mysql_commit(Mysql mysql);
extern fn Mysql         mysql_init(Mysql mysql);
extern fn CUInt         mysql_errno(Mysql mysql);
extern fn ZString       mysql_error(Mysql mysql);
extern fn MysqlRow      mysql_fetch_row(MysqlRes result);
extern fn void          mysql_free_result(MysqlRes result);
extern fn void          mysql_library_end() @extern("mysql_server_end");
extern fn CInt          mysql_library_init(CInt argc, void* argv, void* groups) @extern("mysql_server_init");
extern fn CUInt         mysql_num_fields(MysqlRes result);
extern fn CInt          mysql_options(Mysql *mysql, MysqlOption option, void *arg);
extern fn CInt          mysql_ping(Mysql mysql);
extern fn Mysql         mysql_real_connect(Mysql mysql, ZString host, ZString user, ZString passwd, ZString db, CUInt port, ZString unix_socket, CULong client_flag);
extern fn CInt          mysql_real_query(Mysql mysql, ZString stmt_str, CULong length);
extern fn bool          mysql_rollback(Mysql mysql);
extern fn MysqlRes      mysql_use_result(Mysql mysql);

// Prepared Statement Functions

struct MysqlBind  {
  CULong *length;   /* output length pointer */
  bool   *is_null;  /* Pointer to null indicator */
  void*   buffer;   /* buffer to get/put data */
                    /* set this if you want to track data truncations happened during fetch */
  bool *error;
  CUChar *row_ptr;  /* for the current data position */
  void* store_param_func;
  void* fetch_result;
  void* skip_result;

  CULong buffer_length;                 /* output buffer length, must be set when fetching str/binary */
  CULong offset;                        /* offset position for char/binary fetch */
  CULong length_value;                  /* Used if length is 0 */
  CUInt  param_number;                  /* For null count and error messages */
  CUInt  pack_length;                   /* Internal length for packed data */
  CInt   buffer_type;                   /* buffer type */ // ENUM enum_field_types
  bool   error_value;                   /* used if error is 0 */
  bool   is_unsigned;                   /* set if integer type is unsigned */
  bool   long_data_used;                /* If used with mysql_send_long_data */
  bool   is_null_value;                 /* Used if is_null is 0 */
  void *extension;
}

extern fn CULong        mysql_stmt_affected_rows(MysqlStmt stmt);
extern fn bool          mysql_stmt_bind_param(MysqlStmt stmt, MysqlBind* bind);
extern fn bool          mysql_stmt_close(MysqlStmt stmt);
extern fn CInt          mysql_stmt_execute(MysqlStmt stmt);
extern fn CInt          mysql_stmt_fetch(MysqlStmt stmt);
extern fn CInt          mysql_stmt_fetch_column(MysqlStmt stmt, MysqlBind* bind, CUInt column, CULong offset);
extern fn CUInt         mysql_stmt_field_count(MysqlStmt stmt);
extern fn bool          mysql_stmt_free_result(MysqlStmt stmt);
extern fn MysqlStmt     mysql_stmt_init(Mysql mysql);
extern fn CInt          mysql_stmt_next_result(MysqlStmt stmt);
extern fn CInt          mysql_stmt_prepare(MysqlStmt stmt, ZString stmt_str, CULong length);
extern fn CInt          mysql_stmt_store_result(MysqlStmt stmt);
extern fn bool          mysql_stmt_bind_result(MysqlStmt stmt, MysqlBind *bind);
