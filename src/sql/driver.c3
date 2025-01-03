module sql;

import std::io;
import std::collections::map;

map::HashMap(<String, Driver>) registry @private;

<*
	Called from the driver implementation to be registered under `driver_id`.
	@param [in] driver_id `The id of the driver it wants to use`
	@param [in] driver `The driver object, must conform to the "Driver" interface`
*>
fn void register_driver(String driver_id, Driver driver)
{
	registry.set(driver_id, driver);
}

fn void deallocate_drivers() @finalizer @private {
	registry.@each(; String driver_id, Driver driver)
	{
		driver.free();
	};
}

<*
	opens a connection to a database.
	@param [in] driver_id `The id of the driver to use, i.e. "postgres", "mysql", "sqlite"`
	@param [in] connection_string `The connection string as a URL`
*>
fn Connection! open(String driver_id, String connection_string)
{
	Driver! driver = registry.get(driver_id);
	if (catch driver) {
		return Error.UNKNOWN_DRIVER?;
	}
	return driver.open(connection_string);
}
