-- Runs once, on first initialization of an empty data directory.
-- Traccar's schema migration detects the extension and migrates
-- tc_positions / tc_events to hypertables.
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Query planning/execution statistics for operational diagnostics.
-- The image preloads pg_stat_statements at server startup.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
