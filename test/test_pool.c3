module pooltest @test @if(!$feature(NO_PQ));

import std::thread;
import std::time;
import sql;


fn void! test_create_pool()
{
	Pool* pool = sql::create_pool("postgres", "postgres://postgres@localhost/postgres", 1, 1000 * time::MS)!;

	assert(pool != null, "Pool was null");
	assert(pool.conns_pooled() == 0, "There should be no connections");
	assert(pool.max_open_conns == 1, "Capacity should be 1");
	assert(pool.conns_available() == 1, "There should be 1 available connection");

	Connection conn = pool.acquire()!;

	assert(conn != null, "Connection was null");
	assert(pool.conns_pooled() == 1, "There should be 1 open connection");
	assert(pool.conns_available() == 0, "There should be no available connections");

	conn.ping()!;
	pool.release(conn)!;

	assert(pool.conns_inuse.len() == 0, "After close, there should be no more used connections");
	assert(pool.conns_unused.len() == 1, "After close, there should be 1 available connections");

	pool.free()!;
}


fn void! test_pool_exhaust()
{
mem::@report_heap_allocs_in_scope($feature(MEMCHECK)) {
	usz capacity = 3;
	Pool* pool = sql::create_pool("postgres", "postgres://postgres@localhost/postgres", capacity, 1000 * time::MS)!;

	assert(pool.max_open_conns == capacity, "Capacity should be %d", capacity);

	// Trying to exhause pool
	for (usz i = 0; i < capacity; i++)
	{
		Connection conn = pool.acquire()!;
		conn.ping()!;
	}

	// This should fail
	if (catch candidate = pool.acquire())
	{
		if (!(candidate == sql::Error.POOL_EXHAUSTED))
		{
			assert(false, "unexpected fault: %s", candidate);
		}
	}
	else
	{
		assert(false, "pool should have been exhausted, current capacity: %d, max. capacity: %d", pool.conns_pooled(), pool.max_open_conns);
	}

	usz current_size = pool.conns_pooled();
	assert(current_size == capacity, "pool is not at capacity %d, but: %d", capacity, current_size);

	pool.free()!;
};
}

fn void! test_pool_thread()
{
	Pool* pool = sql::create_pool("postgres", "postgres://postgres@localhost/postgres", 1, 1000 * time::MS)!;

	Connection conn = pool.acquire()!;
	conn.ping()!;

	assert(pool.conns_inuse.len() == 1, "There should be 1 used connection");
	assert(pool.conns_unused.len() == 0, "There should be no available connections");

	pool.release(conn)!;

	assert(pool.conns_inuse.len() == 0, "There should be no used connections");
	assert(pool.conns_unused.len() == 1, "There should be 1 available connection");

	// Now wait a bit and see if the connection was closed
	thread::sleep_ms(1500);

	assert(pool.conns_inuse.len() == 0, "There should be no used connections");
	assert(pool.conns_unused.len() == 0, "There should be no available connections");

	pool.free()!;
}