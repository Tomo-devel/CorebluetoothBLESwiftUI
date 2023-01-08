//
//  PeripheralView.swift
//  CorebluetoothBLESwiftUI
//
//  Created by cmStudent on 2023/01/08.
//

import SwiftUI

struct PeripheralView: View {
    @StateObject var peripheral: PeripheralViewModel = PeripheralViewModel()
    
    var body: some View {
        
        VStack {
            TextEditor(text: $peripheral.message)
                .padding(20)
            
            Toggle("Advertising", isOn: $peripheral.toggleFrag)
                .padding(20)
                .onChange(of: peripheral.toggleFrag) { newValue in
                    peripheral.switchChanged()
                }
        }
        .onDisappear {
            peripheral.stopAction()
        }
    }
}

struct PeripheralView_Previews: PreviewProvider {
    static var previews: some View {
        PeripheralView()
    }
}
