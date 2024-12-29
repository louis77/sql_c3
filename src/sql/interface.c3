module sql;

<*
    The Driver interface defines the methods that a SQL driver must implement
    for managing connections.
*>
interface Driver
{
    fn Connection!  open(String connection_string);
    fn void         close(Connection conn);
    fn void!        ping(Connection conn);
}

<*
    The Connection interface defines the methods that a SQL connection must
    implement for executing queries.
*>
interface Connection
{
    fn Result!      query(String command, args...);
    fn usz!         exec(String command, args...);
    fn String       last_error();

    // Optionally, start, commit or rollback transactions
    fn void!        tx_begin();
    fn void!        tx_commit();
    fn void!        tx_rollback();
    fn bool         tx_in_progress();
}

<*
    The Result interface defines the methods that a SQL result must implement
    for iterating over rows.
*>
interface Result
{
    fn bool         next();
    fn void!        scan(int fieldnum, any dest);
    fn void         close();
}

<*
    Common faults.
*>
fault Error
{
    CONNECTION_FAILURE,
    NOT_IMPLEMENTED,
    COMMAND_FAILED,
    PARAM_BINDING_FAILED,
    UNSUPPORTED_SCAN_TYPE,
    UNSUPPORTED_BIND_TYPE,
    ILLEGAL_COLUMN_ACCESS,
    PREPARE_FAILED,
    UNKNOWN_ERROR,
    TX_ALREADY_IN_PROGRESS,
}