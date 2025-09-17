//
//  DateRangePicker.swift
//  Job Tracking Cable South
//
//  Created by Quinton  Thompson  on 2/3/25.
//

import SwiftUI

struct DateRangePicker: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @State private var internalStartDate = Date()
    @State private var internalEndDate = Date()

    var body: some View {
        VStack {
            DatePicker("Start Date", selection: $internalStartDate, displayedComponents:.date)
              .padding()
              .onChange(of: internalStartDate) { newValue in
                    startDate = newValue
                    if let endDate = endDate, newValue > endDate {
                        internalEndDate = newValue
                        self.endDate = newValue
                    }
                }

            DatePicker("End Date", selection: $internalEndDate, displayedComponents:.date)
              .padding()
              .onChange(of: internalEndDate) { newValue in
                    endDate = newValue
                    if let startDate = startDate, newValue < startDate {
                        internalStartDate = newValue
                        self.startDate = newValue
                    }
                }
        }
      .onAppear {
            if let startDate = startDate {
                internalStartDate = startDate
            }
            if let endDate = endDate {
                internalEndDate = endDate
            }
        }
    }
}
