//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        configureUI()
        
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            appDelegate.userName = usernameTextField.text!
            appDelegate.passWord = passwordTextField.text!
            
            /*
             Steps for Authentication...
             https://www.themoviedb.org/documentation/api/sessions
             
             Step 1: Create a request token
             Step 2: Ask the user for permission via the API ("login")
             Step 3: Create a session ID
             
             Extra Steps...
             Step 4: Get the user id ;)
             Step 5: Go to the next view!
             */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "MoviesTabBarController") as! UITabBarController
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        // if an error occurs, print it and re-enable the UI
        func displayError(_ error: String) {
            print(error)
            performUIUpdatesOnMain {
                self.setUIEnabled(true)
                self.debugTextLabel.text = "Login Failed (Reqst Token)."
            }
        }
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            /* 5. Parse the data */
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request: \(error!)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: [String: AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String : AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else {
                displayError("Could not find key '\(Constants.TMDBResponseKeys.Success)'")
                return
            }
            
            guard let token = parsedResult[Constants.TMDBResponseKeys.RequestToken] as? String else {
                displayError("Could not find key '\(Constants.TMDBResponseKeys.RequestToken)'")
                return
            }
            
            print("TOKEN: \(token)")
            
            /* 6. Use the data! */
            self.appDelegate.requestToken = token
            self.loginWithToken(self.appDelegate.requestToken!)
        }
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func loginWithToken(_ requestToken: String) {
        
        /* TASK: Login, then get a session id */
        
        // if an error occurs, print it and re-enable the UI
        func displayError(_ error: String) {
            print(error)
            performUIUpdatesOnMain {
                self.setUIEnabled(true)
                self.debugTextLabel.text = "Login Failed (Session Invalid)."
            }
        }
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.Username: appDelegate.userName,
            Constants.TMDBParameterKeys.Password: appDelegate.passWord,
            Constants.TMDBParameterKeys.RequestToken: appDelegate.requestToken
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/authentication/token/validate_with_login"))
        
        /* 4. Make the request */
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request: \(error!)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!\(String(describing: response))")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            /* 5. Parse the data */
            let parsedResult: [String: AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String : AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            //print("jason: \(parsedResult)")
            
            guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else {
                displayError("Could not find key \(Constants.TMDBResponseKeys.Success)")
                return
            }
            
            /* 6. Use the data! */
            self.getSessionID(self.appDelegate.requestToken!)
            print("loged in, now get the session id")
        }
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func getSessionID(_ requestToken: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        func displayError(_ error: String) {
            print(error)
            performUIUpdatesOnMain {
                self.setUIEnabled(true)
                self.debugTextLabel.text = "Login Failed (Session ID)"
            }
        }
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.RequestToken: appDelegate.requestToken
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/authentication/session/new"))
        
        /* 4. Make the request */
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            /* GUARD: Was there an error?*/
            guard error == nil else {
                displayError("There was an eror with your request: \(String(describing: error))")
                return
            }
            /* GUARD: Did we get a successful 2xx response? */
            guard let httpStatusCode = (response as? HTTPURLResponse)?.statusCode, httpStatusCode >= 200 && httpStatusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!\(String(describing: response))")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let jasonData = data else {
                displayError("No data was return by the request!")
                return
            }
            
            /* 5. Parse the data */
            let parsedResult: [String: AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: jasonData, options: .allowFragments) as! [String: AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(jasonData)'")
                return
            }
            
            /* GAURD: Was json response key success 'true'? */
            guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else {
                displayError("Could not find key '\(Constants.TMDBResponseKeys.Success)'")
                return
            }
            
            /* GUARD: Was session id returned? */
            guard let sessionID = parsedResult[Constants.TMDBResponseKeys.SessionID] as? String else {
                displayError("Could not find key '\(Constants.TMDBResponseKeys.SessionID)'")
                return
            }
            
            /* 6. Use the data! */
            self.appDelegate.sessionID = sessionID
            self.getUserID(self.appDelegate.sessionID!)
        }
        
        /* 7. Start the request */
        task.resume()
    }
    
    private func getUserID(_ sessionID: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        func displayError(_ error: String) {
            print(error)
            performUIUpdatesOnMain {
                self.setUIEnabled(true)
                self.debugTextLabel.text = "Login Failed (User ID)"
            }
        }
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.SessionID: appDelegate.sessionID
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let requset = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String : AnyObject], withPathExtension: "/account"))
        
        /* 4. Make the request */
        let task = URLSession.shared.dataTask(with: requset) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard error == nil else {
                displayError("There was an error with your request '\(String(describing: error))'")
                return
            }
            
            /* GUARD: Did we get successful 2xx response? */
            guard let httpStatusCode = (response as? HTTPURLResponse)?.statusCode, httpStatusCode >= 200 && httpStatusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!\(String(describing: response))")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let returnedData = data else {
                displayError("No data returned by the request!")
                return
            }
            
            /* 5. Parse the data */
            let json: [String: AnyObject]!
            do{
                json = try JSONSerialization.jsonObject(with: returnedData, options: .allowFragments) as! [String: AnyObject]
            } catch {
                displayError("Could not pasrse data as JSON: '\(returnedData)'")
                return
            }
            
            guard let userID = json[Constants.TMDBResponseKeys.UserID] as? Int else {
                displayError("Could not get value for key '\(Constants.TMDBResponseKeys.UserID)'")
                return
            }
            
            /* 6. Use the data! */
            self.appDelegate.userID = userID
            self.completeLogin()
        }
        
        /* 7. Start the request */
        task.resume()
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.isHidden = true
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.isHidden = false
        }
    }
    
    @objc func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    @objc func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    private func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

private extension LoginViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        usernameTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        loginButton.isEnabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.isEnabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    func configureTextField(_ textField: UITextField) {
        let textFieldPaddingViewFrame = CGRect(x: 0.0, y: 0.0, width: 13.0, height: 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSAttributedStringKey.foregroundColor: UIColor.white])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

private extension LoginViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
