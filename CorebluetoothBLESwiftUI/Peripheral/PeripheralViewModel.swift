//
//  PeripheralViewModel.swift
//  CorebluetoothBLESwiftUI
//
//  Created by cmStudent on 2023/01/08.
//

import Foundation
import CoreBluetooth
import os

class PeripheralViewModel: NSObject, ObservableObject {
    
    @Published var message: String = ""
    @Published var toggleFrag: Bool = false
    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
    func switchChanged() {
        if toggleFrag {
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
            
        } else {
            stopAction()
        }
    }
    
    func stopAction() {
        peripheralManager.stopAdvertising()
    }
    
    private func setUpPeripheral() {
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.characteristicUUID,
                                                             properties: [.notify, .writeWithoutResponse],
                                                             value: nil,
                                                             permissions: [.readable, .writeable])
        // サービスの作成
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        // サービスにcharacteristicsを追加
        transferService.characteristics = [transferCharacteristic]
        // periphralManagerに追加
        peripheralManager.add(transferService)
        
        self.transferCharacteristic = transferCharacteristic
    }
    
    static var sendingEOM = false
    
    private func sendData() {
        
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        
        // EOMを送信する必要があるかどうかを確認
        if PeripheralViewModel.sendingEOM {
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            if didSend {
                PeripheralViewModel.sendingEOM = false
                print("Sent: EOM")
            }
            return
        }
        
        if sendDataIndex >= dataToSend.count {
            return
        }
        
        var didSend = true
        while didSend {
            
            var amountToSend = dataToSend.count - sendDataIndex
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }
            
            // データをコピー
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            // うまくいかなかった場合は、コールバックを待つ
            if !didSend {
                return
            }
            
            let stringFromData = String(data: chunk, encoding: .utf8)
            print("Sent \(chunk.count) bytes: \(String(describing: stringFromData))")
            
            // 送信されたらインデックスを更新
            sendDataIndex += amountToSend
           
            if sendDataIndex >= dataToSend.count {
                
                // 送信に失敗した場合、次回送信できるように設定
                PeripheralViewModel.sendingEOM = true
                
                // 送信
                let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                            for: transferCharacteristic, onSubscribedCentrals: nil)
                if eomSent {
                    // 終わり
                    PeripheralViewModel.sendingEOM = false
                    print("Sent: EOM")
                }
                return
            }
        }
    }
}


extension PeripheralViewModel: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print(".powerOn")
            setUpPeripheral()
            return
            
        case .poweredOff :
            print(".powerOff")
            return
            
        case .resetting:
            print(".restting")
            return
            
        case .unauthorized:
            print(".unauthorized")
            return
            
        case .unknown:
            print(".unknown")
            return
            
        case .unsupported:
            print(".unsupported")
            return
            
        default:
            print("A previously unknown central manager state occurred")
            return
        }
    }
    
    // characteristicが読み込まれたときにキャッチ、データの送信を開始
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
        
        if let message = message.data(using: .utf8) {
            dataToSend = message
        }
     
        sendDataIndex = 0
        
        connectedCentral = central
        
        // 送信開始
        sendData()
    }
    
    // セントラルが停止したときに認識
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
        connectedCentral = nil
    }
    
    // peripheralManagerが次のデータを送信する準備ができたときに呼び出される。
    // パケットが送信された順番に到着することを保証するためのもの
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
    
    // peripheralManagerがcharacteristicsへの書き込みを受信したときに入力
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for aRequest in requests {
            guard let requestValue = aRequest.value,
                  let stringFromData = String(data: requestValue, encoding: .utf8) else {
                continue
            }
            
            print("Received write request of \(requestValue.count) bytes: \(stringFromData)")
            message = stringFromData
        }
    }
}

