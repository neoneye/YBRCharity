//
//  MainViewController.swift
//  YBRCharity
//
//  Created by 李冬 on 16/1/28.
//  Copyright © 2016年 李冬. All rights reserved.
//

import UIKit
import TrelloNavigation
import SwiftyDrop
import Alamofire
import SwiftyJSON

class MainViewController: UIViewController {

	var trelloView : TrelloView?

	private let reuseIdentifier = "TrelloListCell"

	let ScreenWidth = UIScreen.mainScreen().bounds.size.width

	let ScreenHeight = UIScreen.mainScreen().bounds.size.height

	var profileViewController : ProfileViewController!

	// 登录弹出视图
	var popup : AFPopupView!

	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.

		NSNotificationCenter.defaultCenter().addObserver(self, selector: "hidePopup:", name: "HideAFPopup", object: nil)

		// 发送验证码
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "sendConfirmCode:", name: "SendConfirmCode", object: nil)

		// 验证验证码
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "checkConfirmCode:", name: "ConfirmCode", object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "showTipMessage:", name: "DropMessage", object: nil)

		view.backgroundColor = TrelloDeepBlue
		self.trelloView = TrelloView(frame: CGRectMake(0, 0, ScreenWidth, ScreenHeight), tabCount: 5, trelloTabCells: { () -> [UIView] in
			return [
				TrelloListTabViewModel.tabView("BACKLOG", level: 3),
				TrelloListTabViewModel.tabView("BRIEFS", level: 5),
				TrelloListTabViewModel.tabView("DESIGN", level: 2),
				TrelloListTabViewModel.tabView("USER TESTING", level: 4),
				TrelloListTabViewModel.tabView("USER TESTIN", level: 1)
			]
		})

		if let trelloView = trelloView {
			view.addSubviews(trelloView)
			trelloView.delegate = self
			trelloView.dataSource = self

			var i = 0
			for tableView in trelloView.tableViews {
				guard let tableView = tableView as? TrelloListTableView<TrelloListCellItem> else { return }
				tableView.registerClass(TrelloListTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
				tableView.tab = trelloView.tabs[i]
				tableView.listItems = TrelloData.data[i]
				i++
			}
		}

		self.profileViewController = ProfileViewController()
		self.view.addSubview(profileViewController.view)
		self.profileViewController.setBgRGB(0x000000)
		self.profileViewController.view.frame = self.view.bounds
		self.profileViewController.delegate = self
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		navigationController?.navigationBar.translucent = false
		navigationController?.navigationBar.barTintColor = TrelloBlue
		_ = navigationController?.navigationBar.subviews.first?.subviews.map { view in
			if view is UIImageView {
				view.hidden = true
			}
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	/*
	 // MARK: - Navigation

	 // In a storyboard-based application, you will often want to do a little preparation before navigation
	 override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
	 // Get the new view controller using segue.destinationViewController.
	 // Pass the selected object to the new view controller.
	 }
	 */

	@IBAction func showProfileView(sender: AnyObject) {

		// 判断用户是否已经登录了
		if DataBaseUtil.hasUserLogin() {
			// 动画弹出
			self.profileViewController.showHideSidebar()
			self.profileViewController.playShowInAnimation()
			return
		}

		// 没有用户登录的话就弹出登录视图
		let loginViewController = self.storyboard?.instantiateViewControllerWithIdentifier("LoginViewController") as! LoginViewController
		self.popup = AFPopupView.popupWithView(loginViewController.view)
		self.popup.show()
	}

	// 隐藏
	func hidePopup(notification : NSNotification) {
		self.popup.hide()
	}

	// 显示提醒
	func showTipMessage(notification : NSNotification) {
		let message = notification.userInfo!["message"] as! String
		Drop.down(message, state: DropState.Default)
	}

	func showTipMessageWithString(message : String) {
		Drop.down(message, state: DropState.Default)
	}

	// 发送验证码
	func sendConfirmCode(notification : NSNotification) {
		let phoneNum = notification.userInfo!["phoneNum"] as! String
		SMSSDK.getVerificationCodeByMethod(SMSGetCodeMethodSMS, phoneNumber: phoneNum, zone: "86", customIdentifier: nil) { (error) -> Void in
			if let error = error {
				print(error)
				self.showTipMessageWithString("获取验证码失败，请重试")
			} else {
				self.showTipMessageWithString("获取验证码成功")
				self.popup.updateLoginBtnTitle("登录")
			}
		}
	}

	// 对验证码进行验证
	func checkConfirmCode(notification : NSNotification) {
		SVProgressHUD.show()
		let phoneNum = notification.userInfo!["phoneNum"] as! String
		let confirmCode = notification.userInfo!["confirmCode"] as! String
		SMSSDK.commitVerificationCode(confirmCode, phoneNumber: phoneNum, zone: "86") { (error) -> Void in
			if let error = error {
				print(error)
				self.showTipMessageWithString("验证失败，请重试")
				SVProgressHUD.dismiss()
			} else {
				self.showTipMessageWithString("验证成功")
				// self.popup.updateLoginBtnTitle("登录")
				// self.popup.hide()

				// 请求Login.php
				self.requestLogin(phoneNum, account_type: 0)
			}
		}
	}

	func requestLogin(account : String, account_type : Int) {
		let paras = [
			"account" : account,
			"account_type" : account_type,
			"nick" : account,
			"header" : AppDelegate.DEFAULT_HEADER
		]
		Alamofire.request(.GET, AppDelegate.URL_PREFEX + "login.php", parameters: paras as? [String : AnyObject])
			.responseJSON { response in

				// 返回的不为空
				if let value = response.result.value {
					// 解析json
					let json = JSON(value)
					let code = json["code"].intValue

					print(json)

					// 获取成功
					if code == 200 {
						// 解析信息
						let data = json["data"]
						let user = MyUser()
						user.id = data["id"].intValue
						user.account_type = data["account_type"].intValue
						user.account = data["account"].stringValue
						user.nick = data["nick"].stringValue
						user.header = data["header"].stringValue
						user.authentication = data["authentication"].boolValue
						user.real_name = data["real_name"].stringValue
						user.real_id = data["real_id"].stringValue
						user.phone_num = data["phone_num"].stringValue

						// 插入本地数据库
						DataBaseUtil.updateLocalUser(user)
						self.showTipMessageWithString("登录成功")
						self.popup.hide()
					}
				}
				SVProgressHUD.dismiss()
		}
	}
}

extension MainViewController : UITableViewDelegate, UITableViewDataSource, ProfileViewControllerDelegate {
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let tableView = tableView as? TrelloListTableView<TrelloListCellItem>,
			count = tableView.listItems?.count
		else { return 0 }
		return count
	}

	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 60.0
	}

	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		guard let tableView = tableView as? TrelloListTableView<TrelloListCellItem> else { fatalError("TableView False") }
		guard let item = tableView.listItems?[indexPath.row] else { fatalError("No Data") }

		return (item.image != nil) ? 220.0 : 80.0
	}

	func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let view = TrelloListSectionView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 60.0))
		guard let tableView = tableView as? TrelloListTableView<TrelloListCellItem> else { return view }
		view.title = tableView.tab ?? ""
		return view
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		guard let tableView = tableView as? TrelloListTableView<TrelloListCellItem> else { fatalError("TableView False") }
		guard let item = tableView.listItems?[indexPath.row] else { fatalError("No Data") }
		guard let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as? TrelloListTableViewCell else {
			return TrelloListCellViewModel.initCell(item, reuseIdentifier: reuseIdentifier)
		}
		return TrelloListCellViewModel.updateCell(item, cell: cell)
	}

	func profileViewContrllerHeaderTaped() {
		let selfViewController = self.storyboard?.instantiateViewControllerWithIdentifier("SelfViewController") as! SelfViewController
		self.navigationController?.pushViewController(selfViewController, animated: true)
	}

	func recordBtnClicked() {
		let recordViewController = self.storyboard?.instantiateViewControllerWithIdentifier("RecordViewController") as! RecordViewController
		self.navigationController?.pushViewController(recordViewController, animated: true)
	}
}