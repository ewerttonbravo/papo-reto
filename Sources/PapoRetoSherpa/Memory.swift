import Darwin

/// This process's physical footprint (what Activity Monitor shows), its peak, and resident size, in MB.
public func processMemory() -> (footprint: Double, peak: Double, resident: Double) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    let mb = { (bytes: UInt64) in Double(bytes) / 1_048_576 }
    return (mb(info.phys_footprint), mb(UInt64(info.ledger_phys_footprint_peak)), mb(info.resident_size))
}
