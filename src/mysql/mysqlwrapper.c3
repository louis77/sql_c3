module mysql8;

def Mysql = void*;
def MysqlRes = void*;
def MysqlRow = void**;

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

extern fn CULong        mysql_affected_rows(Mysql *mysql);
extern fn CBool         mysql_autocommit(Mysql *mysql, CBool mode);
extern fn void          mysql_close(Mysql mysql);
extern fn Mysql         mysql_init(Mysql mysql);
extern fn CUInt         mysql_errno(Mysql mysql);
extern fn ZString       mysql_error(Mysql mysql);
extern fn MysqlRow      mysql_fetch_row(MysqlRes *result);
extern fn void          mysql_free_result(MysqlRes result);
extern fn void          mysql_library_end() @extern("mysql_server_end");
extern fn CInt          mysql_library_init(CInt argc, void* argv, void* groups) @extern("mysql_server_init");
extern fn CUInt         mysql_num_fields(MysqlRes *result);
extern fn CInt          mysql_options(Mysql *mysql, MysqlOption option, void *arg);
extern fn Mysql         mysql_real_connect(Mysql mysql, ZString host, ZString user, ZString passwd, ZString db, CUInt port, ZString unix_socket, CULong client_flag);
extern fn CInt          mysql_real_query(Mysql mysql, ZString stmt_str, CULong length);
extern fn MysqlRes      mysql_use_result(Mysql *mysql);
extern fn CInt          mysql_ping(Mysql mysql);