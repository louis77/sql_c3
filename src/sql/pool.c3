module sql;

import std::io;
import std::collections::list;
import std::collections::tuple;
import std::thread;
import std::time;

distinct ConnLastUsed = Tuple(<Connection, Time>);

const THREAD_SLEEP_MS = 50;

<* Pool represents a pool object. *>
struct Pool {
	Mutex mu;
	String driver_id;
	String connection_string;
	List(<Connection>) conns_inuse;
	List(<ConnLastUsed>) conns_unused;
	usz max_open_conns;
	Duration max_idle_timeout;

	Thread manager;
	bool should_close;
}

fn int manager_work(void* args) @private
{
	Pool* pool = (Pool*)args;
	while (!pool.should_close)
	{
		thread::sleep_ms(THREAD_SLEEP_MS);
		pool.mu.lock()!!;

		List(<Connection>) expired_connections;
		expired_connections.new_init(0);
		defer expired_connections.free();

		// Check for expired connections
		foreach (idx, candidate : pool.conns_unused)
		{
			if (candidate.second.add_duration(pool.max_idle_timeout) > time::now())
			{
				expired_connections.push(candidate.first);
			}
		}

		foreach (idx, expired : expired_connections)
		{
			pool.conns_unused.remove_using_test(fn(c, other) => ((ConnLastUsed*)c).first == other, expired);
			expired.close();
		}

		pool.mu.unlock()!!;
	}

	return 0;
}

fn Pool*! create_pool(String driver_id, String connection_string, usz max_open_conns, Duration max_idle_timeout, Allocator allocator=allocator::heap())
{
	Pool* pool = mem::new(Pool);
	pool.mu.init()!;
	pool.driver_id         = driver_id;
	pool.connection_string = connection_string;
	pool.max_open_conns    = max_open_conns;
	pool.max_idle_timeout  = max_idle_timeout;

	pool.conns_inuse.new_init(0, allocator);
	pool.conns_unused.new_init(0, allocator);
	pool.manager.create(&manager_work, pool)!;

	return pool;
}


fn void! Pool.free(&self)
{
	// Shut down the manager
	self.should_close = true;
	// Wait for the manager to stop
	self.manager.join()!;

	self.mu.lock()!;
	self.close_all();
	self.conns_inuse.free();
	self.conns_unused.free();
	self.mu.unlock()!;
	self.mu.destroy()!;
	mem::free(self);
}


fn Connection! Pool.acquire(&self)
{
	self.mu.lock()!;

	ConnLastUsed! candidate = self.conns_unused.pop();

	// First find an unused, open connection
	if (try candidate)
	{
		self.mu.unlock()!;
		return candidate.first;
	}

	// If none is available, try to open a new one
	if (self.conns_inuse.len() >= self.max_open_conns)
	{
		self.mu.unlock()!;
		return Error.POOL_EXHAUSTED?;
	}

	Connection conn = open(self.driver_id, self.connection_string)!;
	self.conns_inuse.push(conn);
	self.mu.unlock()!;
	return conn;
}

fn void! Pool.release(&self, Connection conn)
{
	self.mu.lock()!;

	foreach (idx, candidate : self.conns_inuse)
	{
		if (conn == candidate)
		{
			self.conns_unused.push(ConnLastUsed{.first = candidate, .second = time::now()});
			self.conns_inuse.remove_at(idx);
			break;
		}
	}
	// If the connection was not in use, this is a no-op
	self.mu.unlock()!;
}

fn void Pool.close_all(&self) @private
{
	foreach (idx, &conn : self.conns_inuse)
	{
		conn.close();
	}
	self.conns_inuse.clear();

	foreach (idx, &conn : self.conns_unused)
	{
		conn.first.close();
	}
	self.conns_unused.clear();
}

fn usz Pool.conns_pooled(&self)
{
	usz count = self.conns_inuse.len() + self.conns_unused.len();
	return count;
}

fn usz Pool.conns_available(&self)
{
	usz count = self.max_open_conns - self.conns_pooled();
	return count;
}
