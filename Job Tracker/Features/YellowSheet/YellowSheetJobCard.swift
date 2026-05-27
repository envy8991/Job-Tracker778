import SwiftUI

struct YellowSheetJobCard: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(job.address)
                .font(.headline)
                .foregroundColor(.white)
            
            if let jobNumber = job.jobNumber, !jobNumber.isEmpty {
                Text("Job Number: \(jobNumber)")
                    .font(.subheadline)
                    .foregroundColor(.white)
            } else {
                Text("Job Number: N/A")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            Text("Status: \(job.status)")
                .font(.subheadline)
                .foregroundColor(.white)
            
            if let nid = job.nidFootage, !nid.isEmpty {
                Text("NID Footage: \(nid)")
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            if let can = job.canFootage, !can.isEmpty {
                Text("CAN Footage: \(can)")
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            if (job.nidFootage == nil || job.nidFootage!.isEmpty) &&
               (job.canFootage == nil || job.canFootage!.isEmpty) {
                Text("Footages: N/A")
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            
            if let materials = job.materialsUsed, !materials.isEmpty {
                Text("Materials: \(materials)")
                    .font(.footnote)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.2, green: 0.25, blue: 0.3).opacity(0.75))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
        )
        .padding(.horizontal, 4)
    }
}
