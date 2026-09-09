extends SceneTree
func _initialize() -> void:
    var folder := ProjectSettings.globalize_path("res://../third_party/licenses/")
    var license_file := FileAccess.open(folder+"GODOT-ENGINE-LICENSE.txt",FileAccess.WRITE)
    license_file.store_string(Engine.get_license_text())
    var notices := FileAccess.open(folder+"GODOT-THIRD-PARTY.json",FileAccess.WRITE)
    notices.store_string(JSON.stringify({"copyright":Engine.get_copyright_info(),"licenses":Engine.get_license_info()},"  ")+"\n")
    print("Exported runtime notices for ",Engine.get_version_info().string)
    quit()
