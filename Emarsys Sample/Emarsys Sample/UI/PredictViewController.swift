//
//  Copyright © 2018. Emarsys. All rights reserved.
//

import Foundation
import EmarsysSDK

class PredictViewController: UIViewController {

    //MARK: Outlets
    @IBOutlet weak var tfItemId: UITextField!
    @IBOutlet weak var tfCategoryId: UITextField!
    @IBOutlet weak var tfSearchTerm: UITextField!
    @IBOutlet weak var tvCartItems: UITextView!
    @IBOutlet weak var tfOrderId: UITextField!

    //MARK: Variables
    var cartItems = [EMSCartItem]()

    //MARK: ViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        self.view.addGestureRecognizer(tapGestureRecognizer)

        cartItems.append(generateCartItem())
        cartItems.append(generateCartItem())
        tvCartItems.text = cartItems.description
    }

    //MARK: Actions
    @IBAction func trackItemViewButtonClicked(_ sender: Any) {
        guard let itemId = tfItemId.text, itemId.count > 0 else {
            return
        }
        Emarsys.predict.trackItemView(withItemId: itemId)
    }

    @IBAction func trackCategoryIdButtonClicked(_ sender: Any) {
        guard let categoryId = tfCategoryId.text, categoryId.count > 0 else {
            return
        }
        Emarsys.predict.trackCategoryView(withCategoryPath: categoryId)
    }

    @IBAction func trackSearchTermButtonClicked(_ sender: Any) {
        guard let searchTerm = tfSearchTerm.text, searchTerm.count > 0 else {
            return
        }
        Emarsys.predict.trackSearch(withSearchTerm: searchTerm)
    }

    @IBAction func addCartItemButtonClicked(_ sender: Any) {
        cartItems.append(generateCartItem())
        tvCartItems.text = cartItems.description
    }

    @IBAction func trackCartItemButtonClicked(_ sender: Any) {
        Emarsys.predict.trackCart(withCartItems: cartItems)
    }

    @IBAction func trackPurchaseButtonClicked(_ sender: Any) {
        guard let orderId = tfOrderId.text, orderId.count > 0 else {
            return
        }
        Emarsys.predict.trackPurchase(withOrderId: orderId, items: cartItems)
    }

    //MARK: Privates
    private func generateCartItem() -> EMSCartItem {
        let itemIds = [
            "2185",
            "2186",
            "2187",
            "2188",
            "2189",
            "2190",
            "2191",
            "2192",
            "2193",
            "2194",
            "2195",
            "2196",
            "2197",
            "2198",
            "2199",
            "2200",
            "2201",
            "2202",
            "2206",
            "2209",
            "2210",
            "2211",
            "2213",
            "2215",
            "2231",
            "2232",
            "2233",
            "2235",
            "2236",
            "2237",
            "2239",
            "2240",
            "2241",
            "2244",
            "2289"
        ];
        let price = Double.random(in: 1..<100)
        let quantity = Double.random(in: 1..<5)
        return EMSCartItem(itemId: itemIds[Int.random(in: 0..<itemIds.count)], price: price, quantity: quantity)
    }

    @objc func backgroundTapped() {
        self.view.endEditing(true)
    }
}
