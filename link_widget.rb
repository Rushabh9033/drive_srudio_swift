require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
widget_group = project.main_group.find_subpath('DriveStudioWidget', false)

if runner_target && widget_group
  file_ref = widget_group.files.find { |f| f.path == 'DriveStudioWidget.swift' || f.name == 'DriveStudioWidget.swift' }
  if file_ref
    unless runner_target.source_build_phase.files_references.include?(file_ref)
      puts "Adding DriveStudioWidget.swift to Runner target"
      runner_target.source_build_phase.add_file_reference(file_ref)
    end
  else
    puts "File ref not found in group"
  end
end

project.save
