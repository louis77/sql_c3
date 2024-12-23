module sql;

<* 
    The Result interface defines the methods that a SQL result must implement
    for iterating over rows.
*>

interface Result {
    fn bool         next();
    fn void!        scan(int fieldnum, any dest);
}

<*
    The Connection interface defines the methods that a SQL connection must
    implement for executing queries.
*>
interface Connection {
    fn Result!      query(String command);
}

<*
    The Driver interface defines the methods that a SQL driver must implement
    for managing connections.
*>
interface Driver {
    fn Connection!  open(String connection_string);
    fn void         close(Connection conn);
    fn void!        ping(String connection_string); // Not sure if this shouldn't rather take a Connection instead
} 
