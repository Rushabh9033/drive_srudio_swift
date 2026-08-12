require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

# REMOVE ALL .wav FILES FROM RESOURCES
resources_build_phase = target.resources_build_phase
resources_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path && build_file.file_ref.path.end_with?('.wav')
    puts "Removing build file: #{build_file.file_ref.path}"
    resources_build_phase.remove_build_file(build_file)
  end
end

# REMOVE ALL .wav FILES FROM GROUPS
project.main_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXFileReference) && child.path && child.path.end_with?('.wav')
    puts "Removing reference: #{child.path}"
    child.remove_from_project
  end
end

project.save
puts "Successfully purged ALL wavs"
