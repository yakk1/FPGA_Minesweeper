# Define project name and output directory
set project_name "Minesweeper"
set build_dir "../build"

# Create the project in the build directory
# Part number for arty z7-20
create_project -force $project_name $build_dir -part xc7z020clg400-1

# Source files
add_files [glob ../src/*.sv]

# Mem Files
add_files [glob ../src/mem/*.mem]

# IP files (.xci files)
add_files [glob ../ip/**/*.xci]

# Constraints
add_files -fileset constrs_1 [glob ../constraints/*.xdc]

# Generate the underlying files for the Xilinx IP
generate_target all [get_ips]

# Set the top module (replace with your actual top module name)
set_property top top [current_fileset]
puts "Project generation complete!"