require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

files_to_add = [
  'ios/Runner/DeviceStatusChannel.swift',
  'ios/Runner/AppleMusicChannel.swift',
  'ios/Runner/MapsLauncherChannel.swift',
  'ios/Runner/CalendarChannel.swift',
  'ios/Runner/WeatherChannel.swift',
  'ios/Runner/MapKitSearchChannel.swift',
  'ios/Runner/DriveActivityChannel.swift',
  'ios/Runner/DriveAppIntents.swift'
]

group = project.main_group.find_subpath(File.join('Runner'), true)

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  # Check if file is already in the project
  unless group.files.any? { |f| f.path == file_name }
    file_reference = group.new_reference(file_name)
    target.add_file_references([file_reference])
    puts "Added #{file_name} to target"
  else
    puts "#{file_name} already in target"
  end
end

# Bump deployment target to 16.0 for both Runner and Pods if necessary
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
end

project.save
puts "Successfully updated project.pbxproj"
