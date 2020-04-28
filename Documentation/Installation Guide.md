# Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a dependency manager built into Xcode.

If you are using Xcode 11 or higher, go to **File / Swift Packages / Add Package Dependency...** and enter package repository URL **https://github.com/kean/Future.git**, then follow the instructions.

To remove the dependency, select the project and open **Swift Packages** (which is next to **Build Settings**). You can add and remove packages from this tab.

> Swift Package Manager can also be used [from the command line](https://swift.org/package-manager/).

# Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Future into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "kean/Future" ~> 1.0
```

Run `carthage update` to build the framework and drag the built `Future.framework` into your Xcode project.

# Manually

If you prefer not to use either of the aforementioned dependency managers, you can integrate Future into your project manually.

## Embedded Framework

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

```bash
$ git init
```

- Add Future as a git [submodule](http://git-scm.com/docs/git-submodule) by running the following command:

```bash
$ git submodule add https://github.com/kean/Future.git
```

- Open the new `Future` folder, and drag the `Future.xcodeproj` into the Project Navigator of your application's Xcode project.

> It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.

- Select the `Future.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- You will see two different `Future.xcodeproj` folders each with two different versions of the `Future.framework` nested inside a `Products` folder.

> It does not matter which `Products` folder you choose from, but it does matter whether you choose the top or bottom `Future.framework`.

- Select the top `Future.framework` for iOS and the bottom one for OS X.

> The `Future.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.
