import Foundation

var url = URL(fileURLWithPath: "/var/containers/Bundle/Application/uuid/MyApp.app/PlugIns/MyWidget.appex")
url.deleteLastPathComponent()
url.deleteLastPathComponent()
url.appendPathComponent("Frameworks/App.framework/flutter_assets/assets/backgrounds/carbon_weave.png")
print(url.path)
