#!/bin/bash

# Path to the database.yml file
file_path="config/database.yml"

# Check if the file exists
if [[ ! -f "$file_path" ]]; then
  echo "YAML file not found!" 1>&2
  exit 1
fi

# Create a backup
cp "$file_path" "${file_path}.bak.yml"

# Read the current database name from the development section
original_db_name=$(awk '/^development:/ {found=1} found && /^  database:/ && !/solid_queue/ { gsub(/.*database: /, ""); print; exit }' "$file_path")

# Check if 'primary' and 'queue' are already configured in the development section
primary_exists=$(awk '/^development:/ {found=1} found && /^  primary:/ {print "yes"; exit} /^[^ ]/ && !/^development:/ {found=0}' "$file_path")
queue_exists=$(awk '/^development:/ {found=1} found && /^  queue:/ {print "yes"; exit} /^[^ ]/ && !/^development:/ {found=0}' "$file_path")

if [[ -n "$primary_exists" && -n "$queue_exists" ]]; then
  echo "Database yml already configured :)" 1>&2
  exit 0
fi

echo "Configuring database yml file..." 1>&2

# Extract the base database name (remove _dev, _prod suffixes)
dev_db_name=$(echo "$original_db_name")

production_db_name=$(awk '/^production:/ {found=1} found && /^  database:/ && !/solid_queue/ { gsub(/.*database: /, ""); print; exit }' "$file_path")

# Create temporary file
temp_file=$(mktemp)

# Process the file section by section
awk -v dev_db_name="$dev_db_name" -v production_db_name="$production_db_name" '
BEGIN { in_development=0; in_production=0; development_done=0; production_done=0 }

/^development:/ {
    in_development=1
    print "development: &dev"
    print "  primary:"
    print "    <<: *default"
    print "    database: " dev_db_name
    print "  queue:"
    print "    <<: *default"
    print "    database: solid_queue_dev_"dev_db_name
    print "    migrations_paths: []"
    print "    processing_delay_time: 20"
    development_done=1
    next
}

/^production:/ {
    in_production=1
    print "production:"
    print "  primary:"
    print "    <<: *default"
    print "    database: " production_db_name
    print "  queue:"
    print "    <<: *default"
    print "    database: solid_queue_prod_" production_db_name
    print "    migrations_paths: db/queue_migrate"
    print "    processing_delay_time: 20"
    production_done=1
    next
}

# Skip lines within sections we are replacing
in_development && /^  / { next }
in_production && /^  / { next }

# Reset section flags when we hit a new top-level key
/^[^ ]/ {
    in_development=0
    in_production=0
}

# Print all other lines
{ print }
' "$file_path" > "$temp_file"

mv "$temp_file" "$file_path"
echo "YAML file updated successfully." 1>&2

rails streaming:setup