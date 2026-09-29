import Contacts
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var contactsChannel: FlutterMethodChannel?
  private var ussdChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerContactsChannel(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
    registerUssdChannel(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func registerUssdChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "budgetify/ussd",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "ussd_unavailable",
            message: "The phone service is unavailable.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "prepareUssd":
        result(true)
      case "launchUssd":
        let code = call.arguments as? [String: Any]
        self.openUssdPrompt(
          code: code?["code"] as? String,
          result: result
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    ussdChannel = channel
  }

  private func openUssdPrompt(
    code: String?,
    result: @escaping FlutterResult
  ) {
    guard
      let code,
      code.hasPrefix("*182*"),
      code.hasSuffix("#")
    else {
      result(
        FlutterError(
          code: "invalid_ussd",
          message: "Invalid MTN USSD command.",
          details: nil
        )
      )
      return
    }

    var allowedCharacters = CharacterSet.decimalDigits
    allowedCharacters.insert(charactersIn: "*")

    guard
      let encodedCode = code.addingPercentEncoding(
        withAllowedCharacters: allowedCharacters
      ),
      let url = URL(string: "tel:\(encodedCode)")
    else {
      result(
        FlutterError(
          code: "invalid_ussd_url",
          message: "The MTN USSD command could not be opened.",
          details: nil
        )
      )
      return
    }

    UIApplication.shared.open(url, options: [:]) { opened in
      if opened {
        result(nil)
      } else {
        result(
          FlutterError(
            code: "phone_unavailable",
            message: "The Phone app could not open the MTN USSD command.",
            details: nil
          )
        )
      }
    }
  }

  private func registerContactsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "budgetify/contacts",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "contacts_unavailable",
            message: "The contacts service is unavailable.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "authorizationStatus":
        result(self.contactsAuthorizationStatus())
      case "requestPermission":
        self.requestContactsPermission(result: result)
      case "getContacts":
        self.getContacts(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    contactsChannel = channel
  }

  private func contactsAuthorizationStatus() -> String {
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .notDetermined:
      return "notDetermined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "granted"
    @unknown default:
      return "denied"
    }
  }

  private func requestContactsPermission(result: @escaping FlutterResult) {
    let store = CNContactStore()

    store.requestAccess(for: .contacts) { granted, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "contacts_permission_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }

        result(granted)
      }
    }
  }

  private func getContacts(result: @escaping FlutterResult) {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      result(
        FlutterError(
          code: "contacts_permission_denied",
          message: "Contact access has not been granted.",
          details: nil
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let store = CNContactStore()
      let formatterKeys = CNContactFormatter.descriptorForRequiredKeys(
        for: .fullName
      )
      let keysToFetch = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        formatterKeys,
      ]
      let request = CNContactFetchRequest(keysToFetch: keysToFetch)
      request.sortOrder = .userDefault
      var contacts = [[String: String]]()

      do {
        try store.enumerateContacts(with: request) { contact, _ in
          let formattedName = CNContactFormatter.string(
            from: contact,
            style: .fullName
          )?.trimmingCharacters(in: .whitespacesAndNewlines)
          let nameParts = [
            contact.givenName,
            contact.middleName,
            contact.familyName,
          ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
          let nickname = contact.nickname.trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          let resolvedName: String

          if let formattedName = formattedName, !formattedName.isEmpty {
            resolvedName = formattedName
          } else if !nameParts.isEmpty {
            resolvedName = nameParts.joined(separator: " ")
          } else if !nickname.isEmpty {
            resolvedName = nickname
          } else {
            resolvedName = "Unknown contact"
          }

          for (index, labeledNumber) in contact.phoneNumbers.enumerated() {
            let phoneNumber = labeledNumber.value.stringValue
              .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !phoneNumber.isEmpty else {
              continue
            }

            contacts.append([
              "id": "\(contact.identifier)-\(index)",
              "name": resolvedName,
              "phoneNumber": phoneNumber,
            ])
          }
        }

        contacts.sort {
          ($0["name"] ?? "").localizedCaseInsensitiveCompare(
            $1["name"] ?? ""
          ) == .orderedAscending
        }

        DispatchQueue.main.async {
          result(contacts)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "contacts_read_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}
