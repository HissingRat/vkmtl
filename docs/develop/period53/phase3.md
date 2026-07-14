# Period 53 Phase 3: Device Identity And Peer Topology

Status: complete.

`diagnostics.DeviceTopologyReport` records one selected-device identity and its
native peer-group membership:

- Metal: `registryID`, `peerGroupID`, `peerIndex`, and `peerCount`;
- Vulkan: `deviceUUID`, selected physical-device group index/position/count,
  and `subsetAllocation`.

The report distinguishes identity kind and byte length. It does not expose raw
Metal or Vulkan types. Peer membership is diagnostic; vkmtl still owns one
logical device and does not claim peer memory access, device masks, or
cross-device command submission.
