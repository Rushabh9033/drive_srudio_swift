require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

sounds_dir = 'Runner/Sounds'
group = project.main_group.find_subpath(sounds_dir, true)
# Explicitly set the group's path
group.set_source_tree('<group>')
group.path = 'Runner/Sounds'

Dir.glob("#{sounds_dir}/*.wav").each do |file_path|
  file_name = File.basename(file_path)
  
  unless group.files.any? { |f| f.path == file_name }
    # use new_reference to avoid nested paths
    file_reference = group.new_reference(file_name)
    target.add_resources([file_reference])
    puts "Added resource #{file_name} to target"
  else
    f = group.files.find { |f| f.path == file_name }
    f.set_path(file_name)
    puts "#{file_name} already in target, updated path"
  end
end

project.save
puts "Successfully updated project.pbxproj with correct relative paths"
