require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

files_to_add = [
  'Runner/LayerSettingsSheet.swift',
  'Runner/WidgetLibrarySheet.swift',
  'Runner/BackgroundSheet.swift',
  'Runner/SlotManagerScreen.swift',
  'Runner/BgCutoutService.swift',
  'Runner/LayerEditorOverlay.swift'
]

group = project.main_group.find_subpath(File.join('Runner'), true)

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  unless group.files.any? { |f| f.path == file_name }
    file_reference = group.new_reference(file_name)
    target.add_file_references([file_reference])
    puts "Added #{file_name} to target"
  else
    puts "#{file_name} already in target"
  end
end

project.save
puts "Successfully updated project.pbxproj"
