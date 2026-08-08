require 'xcodeproj'
project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }
group = project.main_group.find_subpath(File.join('Runner'), true)

files_to_remove = [
  'DeviceStatusChannel.swift',
  'AppleMusicChannel.swift',
  'MapsLauncherChannel.swift',
  'CalendarChannel.swift',
  'WeatherChannel.swift',
  'MapKitSearchChannel.swift',
  'DriveActivityChannel.swift',
  'DriveAppIntents.swift'
]

files_to_remove.each do |file_name|
  file_ref = group.files.find { |f| f.path == file_name }
  if file_ref
    target.source_build_phase.files_references.delete(file_ref)
    file_ref.remove_from_project
    puts "Removed #{file_name} from project"
  end
end
project.save
