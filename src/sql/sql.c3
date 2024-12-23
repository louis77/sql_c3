module sql;

import pg;

<*
    The Driver interface defines the methods that a SQL driver should implement.
*>
interface Driver {
    fn void* open(String connection_string);
    fn void close(void* conn);
    fn bool ping(void* conn);
} 
