Below is an example of a README file (README.md) that documents your project, its configuration, and how to run it:

---

# PostgreSQL Logical Replication with PostGIS Demo

This project demonstrates a logical replication setup using PostgreSQL with PostGIS extensions. It replicates two custom tables—**cities** and **roads**—from a master database to a replica database. The project uses Docker Compose to deploy two PostgreSQL containers (one master and one replica).

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Configuration Details](#configuration-details)
- [Master Container](#master-container)
- [Replica Container](#replica-container)
- [Initialization Scripts](#initialization-scripts)
- [Running the Project](#running-the-project)
- [Scaling & Adding New Replicas](#scaling--adding-new-replicas)
- [Monitoring Replication](#monitoring-replication)

## Overview

This project sets up logical replication in PostgreSQL (version 17 with PostGIS 3.5) for two custom tables:
- **cities:** Contains a unique identifier, a name, and a geographic point.
- **roads:** Contains a unique identifier, a road name, a geographic linestring, and a foreign key linking to the `cities` table.

The master database creates a publication for these tables only. The replica database subscribes to that publication to keep its data synchronized with the master.

## Project Structure

```
.
├── docker-compose.yml         # Defines master and replica services.
├── master-init.sql            # Initialization script for the master database.
├── replica-init.sql           # Initialization script for the replica database.
└── README.md                  # This documentation.
```

## Configuration Details

### Master Container

The master service uses the following configuration:

- **Image:** `postgis/postgis:17-3.5`
- **Environment:**
  - `POSTGRES_USER=postgres`
  - `POSTGRES_PASSWORD=postgres`
  - `POSTGRES_DB=master_db`
- **Ports:** Exposes port 5432 on the host.
- **Volumes:**
  - Persists data in the `master-data` volume.
  - Mounts the `master-init.sql` file to initialize the database.
- **Command Parameters:**
  - `wal_level=logical`: Enables logical decoding required for logical replication.
  - `max_replication_slots=20`: Allows up to 20 replication slots for supporting multiple subscriptions.
  - `max_wal_senders=10`: Permits up to 10 concurrent WAL sender processes.

### Replica Container

The replica service uses the following configuration:

- **Image:** `postgis/postgis:17-3.5`
- **Environment:**
  - `POSTGRES_USER=postgres`
  - `POSTGRES_PASSWORD=postgres`
  - `POSTGRES_DB=replica_db`
- **Ports:** Maps container port 5432 to host port 5433.
- **Volumes:**
  - Persists data in the `replica-data` volume.
  - Mounts the `replica-init.sql` file to initialize the database.
- **Command Parameters:**
  - `wal_level=logical`
  - `max_replication_slots=10`
  - `max_wal_senders=10`

## Initialization Scripts

### master-init.sql

This script is run on the master container. It:
- Enables the PostGIS extension.
- Creates the custom tables `cities` and `roads`.
- Creates a publication that replicates only these two tables.

```sql
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

-- Create a publication for only your custom tables:
DROP PUBLICATION IF EXISTS my_publication;
CREATE PUBLICATION my_publication FOR TABLE cities, roads;
```

### replica-init.sql

This script is run on the replica container. It:
- Enables the PostGIS extension.
- Creates the same custom tables (`cities` and `roads`) with identical schemas.
  
```sql
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
```

*Note: After initialization, you must manually create the subscription on the replica.*

## Running the Project

1. **Start the Containers:**

   In your project directory, run:
   ```bash
   docker-compose up -d
   ```
2. **Create the Subscription:**

   Once the containers are running, connect to the replica container:
   ```bash
   docker exec -it pg_replica psql -U postgres -d replica_db
   ```
   Then create the subscription:
   ```sql
   CREATE SUBSCRIPTION my_subscription
   CONNECTION 'host=pg_master port=5432 user=postgres password=postgres dbname=master_db'
   PUBLICATION my_publication;
   ```
3. **Verify Replication:**

   Insert sample data on the master and query the replica to verify that changes are replicated:
   ```sql
   -- On the master:
   INSERT INTO cities (name, geom)
   VALUES ('New York', ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326));

   INSERT INTO roads (name, geom, city_id)
   VALUES ('Broadway', ST_SetSRID(ST_MakeLine(
       ST_MakePoint(-74.0100, 40.7100),
       ST_MakePoint(-73.9950, 40.7150)
   ), 4326), 1);
   ```

   Then on the replica:
   ```sql
   SELECT * FROM cities;
   SELECT * FROM roads;
   ```

## Scaling & Adding New Replicas

PostgreSQL logical replication supports multiple subscribers. To add another replica:

1. **Provision a new PostgreSQL instance** with the same PostGIS version and schema.
2. **Run an initialization script** similar to `replica-init.sql` on the new instance.
3. **Create a new subscription** on the new replica that connects to the master’s publication:
   ```sql
   CREATE SUBSCRIPTION my_subscription_new
   CONNECTION 'host=pg_master port=5432 user=postgres password=postgres dbname=master_db'
   PUBLICATION my_publication;
   ```
4. **Automate** this process using container orchestration (e.g., Kubernetes) or configuration management tools (e.g., Ansible) if needed.

## Monitoring Replication

You can monitor the replication status on the master using:

- **Replication Slots:**
  ```sql
  SELECT slot_name, active, restart_lsn
  FROM pg_replication_slots;
  ```
- **WAL Senders:**
  ```sql
  SELECT pid, application_name, state, sent_lsn, write_lsn, flush_lsn, replay_lsn
  FROM pg_stat_replication;
  ```

