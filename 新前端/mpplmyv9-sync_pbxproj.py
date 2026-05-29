import re
import os

pbxproj_path = "/Users/sunweizhou/Desktop/AI Project/Vela/Vela.xcodeproj/project.pbxproj"

# Read pbxproj
with open(pbxproj_path, "r", encoding="utf-8") as f:
    content = f.read()

# Make backup
with open(pbxproj_path + ".bak", "w", encoding="utf-8") as f:
    f.write(content)

# File specs to add
new_files = [
    {
        "file_ref_id": "0B1001900000000000000090",
        "build_file_id": "0B1000900000000000000090",
        "name": "VelaQuickActionsSheet.swift",
        "path": "Features/SharedComponents/VelaQuickActionsSheet.swift"
    },
    {
        "file_ref_id": "0B1001910000000000000091",
        "build_file_id": "0B1000910000000000000091",
        "name": "WeightLogSheetView.swift",
        "path": "Features/SharedComponents/WeightLogSheetView.swift"
    },
    {
        "file_ref_id": "0B1001920000000000000092",
        "build_file_id": "0B1000920000000000000092",
        "name": "NutritionDetailView.swift",
        "path": "Features/Home/NutritionDetailView.swift"
    },
    {
        "file_ref_id": "0B1001A100000000000000A1",
        "build_file_id": "0B1000A100000000000000A1",
        "name": "LocationManager.swift",
        "path": "Core/Services/LocationManager.swift"
    },
    {
        "file_ref_id": "0B1001A200000000000000A2",
        "build_file_id": "0B1000A200000000000000A2",
        "name": "WeatherService.swift",
        "path": "Core/Services/WeatherService.swift"
    },
    {
        "file_ref_id": "0B1001A300000000000000A3",
        "build_file_id": "0B1000A300000000000000A3",
        "name": "WorkoutDetailView.swift",
        "path": "Features/Training/WorkoutDetailView.swift"
    }
]

# 1. Add to PBXBuildFile section
# We look for /* Begin PBXBuildFile section */
build_file_lines = []
for f in new_files:
    line = f'\t\t{f["build_file_id"]} /* {f["name"]} in Sources */ = {{isa = PBXBuildFile; fileRef = {f["file_ref_id"]} /* {f["name"]} */; }};'
    build_file_lines.append(line)

content = content.replace(
    "/* Begin PBXBuildFile section */",
    "/* Begin PBXBuildFile section */\n" + "\n".join(build_file_lines)
)

# 2. Add to PBXFileReference section
# We look for /* Begin PBXFileReference section */
file_ref_lines = []
for f in new_files:
    line = f'\t\t{f["file_ref_id"]} /* {f["name"]} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f["path"]}; sourceTree = "<group>"; }};'
    file_ref_lines.append(line)

content = content.replace(
    "/* Begin PBXFileReference section */",
    "/* Begin PBXFileReference section */\n" + "\n".join(file_ref_lines)
)

# 3. Add to PBXGroup section (under VelaApp children list)
# Let's locate the line `0B0000110000000000000011 /* VelaApp */ = {`
# and insert under its children list
group_match = re.search(r'(0B0000110000000000000011 /\* VelaApp \*/ = \{[^{]*children = \()', content)
if group_match:
    group_str = group_match.group(1)
    group_children_add = "\n" + "\n".join([f'\t\t\t\t{f["file_ref_id"]} /* {f["name"]} */,' for f in new_files])
    content = content.replace(group_str, group_str + group_children_add)

# 4. Add to PBXSourcesBuildPhase section
# Let's locate `0B0000150000000000000015 /* Sources */ = {` and insert inside its `files` list
sources_match = re.search(r'(0B0000150000000000000015 /\* Sources \*/ = \{[^{]*files = \()', content)
if sources_match:
    sources_str = sources_match.group(1)
    sources_files_add = "\n" + "\n".join([f'\t\t\t\t{f["build_file_id"]} /* {f["name"]} in Sources */,' for f in new_files])
    content = content.replace(sources_str, sources_str + sources_files_add)

# Write back
with open(pbxproj_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Synchronized project.pbxproj successfully!")
