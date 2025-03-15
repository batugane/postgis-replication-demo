-- master-init.sql
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create a table of cities with a point geometry
CREATE TABLE cities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL
);

-- Create a table of roads with a linestring geometry and a foreign key to cities
CREATE TABLE roads (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    geom GEOMETRY(LineString, 4326) NOT NULL,
    city_id INT REFERENCES cities(id)
);

-- Create a publication for logical replication on all tables
CREATE PUBLICATION my_publication FOR ALL TABLES;
