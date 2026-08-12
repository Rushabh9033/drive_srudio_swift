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

# Clean up broken references
group.files.each do |f|
  if missing_files.include?(f.path)
    f.remove_from_project
    puts "Removed broken reference #{f.path}"
  end
end

project.save
puts "Successfully cleaned project.pbxproj"
