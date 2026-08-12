require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

sounds_dir = 'Runner/Sounds'
group = project.main_group.find_subpath(sounds_dir, true)

# Remove all existing file references in this group
group.clear

Dir.glob("#{sounds_dir}/*.wav").each do |file_path|
  file_name = File.basename(file_path)
  
  # Create reference with sourceTree = '<group>'
  # Since group is already resolved, we can just pass the path
  file_reference = group.new_file(file_name)
  target.add_resources([file_reference])
  puts "Added resource #{file_name} to target"
end

project.save
puts "Successfully added sounds properly"
