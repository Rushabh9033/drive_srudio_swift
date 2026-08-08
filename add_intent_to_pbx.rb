require 'xcodeproj'
project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'DriveStudioWidgetExtension' }
if target
  group = project.main_group.find_subpath(File.join('DriveStudioWidget'), false)
  if group
    file_ref = group.new_file('DriveStudioIntents.swift')
    target.source_build_phase.add_file_reference(file_ref)
    project.save
    puts "Successfully added DriveStudioIntents.swift to target"
  else
    puts "Could not find DriveStudioWidget group"
  end
else
  puts "Could not find target DriveStudioWidgetExtension"
end
