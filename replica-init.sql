CREATE EXTENSION IF NOT EXISTS postgis;

-- Create the cities table on the replica
CREATE TABLE IF NOT EXISTS cities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL
);

-- Create the roads table on the replica
CREATE TABLE IF NOT EXISTS roads (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    geom GEOMETRY(LineString, 4326) NOT NULL,
    city_id INT
);
\