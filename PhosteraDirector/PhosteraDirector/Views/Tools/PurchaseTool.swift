//
//  PurchaseTool.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 11/6/23.
//

//import Foundation
//import StoreKit
//class PT {
//    static var shared = PT()
//    @Published private(set) var items = [Product] ()
//    private let productIds = ["Director30DayFreeTrail"]
//    
//    func retrieveProducts() async {
//        do {
//            let products = try await Product.products(for: productIds)
//            self.items = products.sorted(by: { $0.price < $1.price })
//            for product in self.items {
//                Logger.shared.error("In-App Product: \(product.displayName) in \(product.displayPrice)")
//            }
//        } catch {
//            Logger.shared.error(error)
//        }
//    }
//    
//    /// Purchase the in-app product
//      func purchase(_ item: Product) async {
//        do {
//          let result = try await item.purchase()
//          switch result {
//          case .success(let verification):
//            Logger.shared.error("Purchase was a success, now it can be verified.")
//          case .pending:
//            Logger.shared.error("Transaction is pending for some action from the users related to the account")
//          case .userCancelled:
//            Logger.shared.error("Use cancelled the transaction")
//          default:
//            Logger.shared.error("Unknown error")
//          }
//        } catch {
//          Logger.shared.error(error)
//        }
//      }
//    
//    
//}
