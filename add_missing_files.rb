require 'xcodeproj'

project_path = 'Vela.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main app target
target = project.targets.find { |t| t.name == 'Vela' || t.name == 'VelaApp' }

if !target
  puts "Could not find main target"
  exit 1
end

files_to_add = [
  'VelaApp/Core/DesignSystem/VelaScrollTracking.swift',
  'VelaApp/Core/Utilities/PipelineDiagnostics.swift',
  'VelaApp/Health/Mapping/HealthUnitNormalizer.swift',
  'VelaApp/Health/Services/HealthKitSyncEngine.swift',
  'VelaApp/Scoring/DailyPlan/DailyPlanLimiterEngine.swift'
]

files_to_add.each do |file_path|
  parts = file_path.split('/')
  group = project.main_group
  
  parts[0...-1].each do |part|
    existing = group.children.find { |c| c.display_name == part || c.path == part }
    if existing
      group = existing
    else
      group = group.new_group(part, part)
    end
  end
  
  filename = parts.last
  file_ref = group.files.find { |f| f.path == filename }
  if !file_ref
    file_ref = group.new_file(filename)
    puts "Added reference #{file_path} to project group"
  else
    puts "Reference #{file_path} already exists in group"
  end
  
  build_phase = target.source_build_phase
  if !build_phase.files_references.include?(file_ref)
    build_phase.add_file_reference(file_ref)
    puts "Added #{file_path} to build phase"
  else
    puts "#{file_path} already in build phase"
  end
end

project.save
puts "Project saved successfully."
