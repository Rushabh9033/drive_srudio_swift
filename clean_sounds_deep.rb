require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

sounds_dir = 'Runner/Sounds'
group = project.main_group.find_subpath(sounds_dir, true)

missing_files = [
  'spark-line.wav', 'rise.wav', 'soft-exit.wav', 'soft-chime.wav', 
  'summit-ping.wav', 'marker.wav', 'power-down.wav', 'night-close.wav', 'low-pulse.wav',
  'double-beat.wav', 'lane-nudge.wav', 'coast-wind.wav', 'harbor-bell.wav', 'ignition.wav', 'gentle-ping.wav', 'glass-tap.wav', 'end-route.wav'
]

# Find ALL files in the target resources build phase with these names
resources_build_phase = target.resources_build_phase
resources_build_phase.files.each do |build_file|
  next unless build_file.file_ref
  
  if missing_files.include?(build_file.file_ref.path) || missing_files.include?(build_file.file_ref.name)
    puts "Removing build file: #{build_file.file_ref.path || build_file.file_ref.name}"
    resources_build_phase.remove_build_file(build_file)
  end
end

# Then remove from groups
project.main_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    if missing_files.include?(child.path) || missing_files.include?(child.name)
      puts "Removing reference: #{child.path || child.name}"
      child.remove_from_project
    end
  end
end

project.save
puts "Successfully cleaned project.pbxproj deeply"
