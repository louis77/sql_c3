module sql;

import std::io;
import std::collections::map;

map::HashMap(<String, Driver>) registry @private;

fn void register_driver(String driver_id, Driver driver)
{
    registry.set(driver_id, driver);
    io::printfn("Registered driver '%s'", driver_id);
}

fn void deallocate_drivers() @finalizer @private {
    registry.@each(; String driver_id, Driver driver)
    {
        driver.free();
        io::printfn("Unregistered driver '%s'", driver_id);
    };
}

fn Connection! open(String driver_id, String connection_string)
{
    Driver! driver = registry.get(driver_id);
    if (catch driver) {
        return Error.UNKNOWN_DRIVER?;
    }
    return driver.open(connection_string);
}
