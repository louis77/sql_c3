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
    fn Result!      query(String command);
    fn usz!         exec(String command);
    fn String       last_error();
}

<* 
    The Result interface defines the methods that a SQL result must implement
    for iterating over rows.
*>

interface Result 
{
    fn bool         next();
    fn void!        scan(int fieldnum, any dest);
}

<*
    Common faults.
*>

fault Error
{
    CONNECTION_FAILURE,
    NOT_IMPLEMENTED,
    COMMAND_FAILED,
    UNSUPPORTED_SCAN_TYPE,
    ILLEGAL_COLUMN_ACCESS,
}