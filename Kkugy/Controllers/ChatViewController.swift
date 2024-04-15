//
//  ChatViewController.swift
//  Kkugy
//
//  Created by 신승재 on 4/11/24.
//

import UIKit
import CoreData

class ChatViewController: UIViewController {
    
    // MARK: - Properties
    private var tableView: UITableView!
    private var messageTextField: UITextField!
    private var navigationBar: ChatNavigationHeaderView!
    
    private var bottomTextFieldConstraint: NSLayoutConstraint!
    
    var messages: [Message] = []
    var sections: [MessageSection] = []
    var context: NSManagedObjectContext! = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupKeyboardNotifications()
        loadMessages()
        scrollToBottom(animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    
    // MARK: - Function
    func setupUI() {
        view.setGradientBackground()
        view.setTranslucentBackground()
        
        navigationBar = ChatNavigationHeaderView()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.backButtonAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        view.addSubview(navigationBar)
        
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        tableView.backgroundColor = UIColor.clear
        tableView.separatorStyle = .none
        
        let messageInputView = MessageInputView()
        messageInputView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageInputView)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 50),
            
            tableView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            messageInputView.topAnchor.constraint(equalTo: tableView.bottomAnchor),
            messageInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            messageInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            messageInputView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        bottomTextFieldConstraint = messageInputView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 10)
        bottomTextFieldConstraint.isActive = true
        
        messageInputView.onSend = { [weak self] messageText in
            self?.sendNewMessage(text: messageText)
        }
    }
    
    func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    
    func loadMessages() {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        do {
            messages = try context.fetch(request)
            groupMessagesByDate()
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func groupMessagesByDate() {
        sections.removeAll()
        var currentSection: MessageSection?
        
        for message in messages {
            if let section = currentSection, Calendar.current.isDate(section.date, inSameDayAs: message.date!) {
                currentSection?.messages.append(message)
            } else {
                if let section = currentSection {
                    sections.append(section)
                }
                currentSection = MessageSection(date: message.date!, messages: [message])
            }
        }
        if let section = currentSection {
            sections.append(section)
        }
        tableView.reloadData()
    }
    
    func sendNewMessage(text: String) {
        let newMessage = Message(context: context)
        newMessage.text = text
        newMessage.date = Date()
        newMessage.isSender = true
        
        do {
            try context.save()
            messages.append(newMessage)
            groupMessagesByDate()
            scrollToBottom(animated: true)
        } catch {
            print("Error saving message: \(error)")
        }
    }
    
    func scrollToBottom(animated: Bool) {
        guard !sections.isEmpty else { return }
        let lastSection = sections.count - 1
        let lastRow = sections[lastSection].messages.count - 1
        if lastRow >= 0 {
            let indexPath = IndexPath(row: lastRow, section: lastSection)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
        }
    }
    
    func adjustForKeyboard(notification: Notification, show: Bool) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        if show {
            bottomTextFieldConstraint.constant = -keyboardSize.height + view.safeAreaInsets.bottom - 10
        } else {
            bottomTextFieldConstraint.constant = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - @obj Function
    @objc func keyboardWillShow(notification: Notification) {
        adjustForKeyboard(notification: notification, show: true)
        scrollToBottom(animated: true)
        
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        adjustForKeyboard(notification: notification, show: false)
    }
        
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - Extension TableView
extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        let message = sections[indexPath.section].messages[indexPath.row]
        let nextMssageSameMinute = (indexPath.row < sections[indexPath.section].messages.count - 1) && Calendar.current.isDate(message.date!, equalTo: sections[indexPath.section].messages[indexPath.row + 1].date!, toGranularity: .minute)
        
        cell.configure(with: message.text ?? "", date: message.date!, isSender: message.isSender, showTime: !nextMssageSameMinute)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = CenteredSectionHeaderView()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ko_KR")
        let title = formatter.string(from: sections[section].date)
        headerView.setTitle(title)
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
    }
}
