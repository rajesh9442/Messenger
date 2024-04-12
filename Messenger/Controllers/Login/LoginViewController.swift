//
//  LoginViewController.swift
//  Messenger
//
//  Created by Harshawardhan T V on 11/19/22.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame : CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame : CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20,weight: .bold)
        
        return button
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let facebookLoginButton : FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile","email"]
        return button
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: {[weak self] _ in
            guard let strongSelf = self else {
                return
            }
            print("Its all right")
            strongSelf.navigationController?.dismiss(animated: true,completion: nil)
        })
        
        title = "Log In"
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(didTapRegister))
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        
        
        view.addSubview(scrollView)
        
        facebookLoginButton.delegate = self
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        
        
        scrollView.addSubview(facebookLoginButton)
        
        
    }
    
    deinit{
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width-size)/2,y: 110,width: size,height: size)
        emailField.frame = CGRect(x: 30,y: imageView.bottom+10,width: scrollView.width-60,height: 52)
        passwordField.frame = CGRect(x: 30,y: emailField.bottom+10,width: scrollView.width-60,height: 52)
        loginButton.frame = CGRect(x: 30,y: passwordField.bottom+30,width: scrollView.width-60,height: 52)
        facebookLoginButton.frame = CGRect(x: 30,y: loginButton.bottom+30,width: scrollView.width-60,height: 52)
        facebookLoginButton.frame.origin.y = loginButton.bottom+20
    }
    
    @objc private func loginButtonTapped() {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        guard let email = emailField.text, let password = passwordField.text,!email.isEmpty, !password.isEmpty,password.count>=6 else{
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        //Firebase Login
        
        
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {[weak self] authResult,error in
            
            guard let strongSelf = self else {
                return
            }
            
            DispatchQueue.main.async{
                strongSelf.spinner.dismiss()
            }
            
            guard let result = authResult,error == nil else{
                print("Failed to log in user with email:\(email)")
                return
            }
            let user = result.user
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                switch result{
                case .success(let data):
                    guard let userData = data as? [String:Any],
                    let firstName = userData["first_name"] as? String,
                    let lastName = userData["last_name"] as? String else{
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):
                    print("Failed to read data with error \(error)")
                }
                
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            
            
            print("Logged in User:\(user)")
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
        })
    }
    
    func alertUserLoginError(){
        let alert = UIAlertController(title: "Oops",message: "Please enter the information in login",preferredStyle: .alert)
        alert.addAction(UIAlertAction(title:"Dismiss",style:.cancel,handler:nil))
        present(alert,animated: true)
    }
    @objc private func didTapRegister()
    {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
}

extension LoginViewController: UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField{
            passwordField.becomeFirstResponder()
            
        }
        else if textField==passwordField{
            loginButtonTapped()
        }
        
        return true
    }
}

extension LoginViewController: LoginButtonDelegate{
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginKit.FBLoginButton) {
        //nothing
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result:   LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else{
            print("User Failed to Login with facebook")
            return
        }
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me", parameters: ["fields":"email,first_name,last_name,picture.type(large)"], tokenString: token, version: nil, httpMethod: .get)
        
        facebookRequest.start(completion: { _, result, error in
            guard let result = result as? [String:Any],
                  error == nil else{
                print("Failed to make fb graph result")
                return
            }
            print("\(result)")
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture  = result["picture"] as? [String: Any],
                  let data = picture["data"] as? [String:Any],
                  let pictureUrl = data["url"] as? String
            else {
                print("Failed to get email and password")
                return
            }
            
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            
            print(result)
            
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                if !exists {
                    let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser,completion: {success in
                        if success{
                            guard let url = URL(string: pictureUrl) else {
                                return
                            }
                            print("Downloading data from facebook")
                            
                            URLSession.shared.dataTask(with: url, completionHandler: { data, _,_ in
                                guard let data = data else{
                                    print("Failed to get data")
                                    return
                                }
                                print("Got data from facebook")
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, filename:fileName, completion: {result in
                                    switch result {
                                    case .success(let downloadUrl):
                                        UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                        print(downloadUrl)
                                    case .failure(let error):
                                        print("Storage Manager Error:\(error)")
                                    }
                                })
                            }).resume()
                            
                        }
                    })
                }
            })
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credential,completion: {[weak self] authResult, error in
                guard let strongSelf = self else{
                    return
                }
                
                
                guard authResult != nil , error == nil else{
                    print("Facebook MFA maybe needed")
                    
                    return
                }
                print("Successfully logged in")
                strongSelf.navigationController?.dismiss(animated: true,completion: nil)
                //print
                //print
            } )
        })
        
    }
    
    
}
