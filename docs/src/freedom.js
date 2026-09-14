export function bindFreedomProgression(sim) {
  let stableSeconds = 0;
  let lastApplied = sim.state.logisticsRating || 0;

  function shipmentScore() {
    const shipped = sim.state.shipped || 0;
    if (shipped >= 90) return 4;
    if (shipped >= 50) return 3;
    if (shipped >= 25) return 2;
    if (shipped >= 10) return 1;
    return 0;
  }

  function throughputScore() {
    const perMinute = sim.state.metrics?.perMinute || 0;
    if (perMinute >= 5) return 2;
    if (perMinute >= 3) return 1;
    return 0;
  }

  function stabilityScore() {
    if (stableSeconds >= 90) return 2;
    if (stableSeconds >= 30) return 1;
    return 0;
  }

  function contractScore() {
    return Math.min(4, Math.max(0, sim.state.completedContracts || 0) * 2);
  }

  function derivedRating() {
    return Math.min(8, shipmentScore() + throughputScore() + stabilityScore() + contractScore());
  }

  function ensureWarehouseWorkers() {
    const workers = sim.state.workers || [];
    const roles = ['store', 'pick', 'ship', 'store', 'pick'];
    let nextId = workers.reduce((max, worker) => Math.max(max, Number(worker.id) || 0), 0) + 1;
    while (workers.length < 5) {
      const index = workers.length;
      workers.push({
        id: nextId++,
        x: -0.8 + (index % 3) * 0.8,
        z: 2.25 + Math.floor(index / 3) * 0.65,
        task: null,
        carrying: null,
        state: 'idle',
        facing: 0,
        role: roles[index] || 'pick',
      });
    }
    workers.forEach((worker, index) => { worker.role = roles[index] || worker.role || 'pick'; });
  }

  function promoteIfReady() {
    if (sim.state.facilityRank >= 2 || sim.state.logisticsRating < 8) return;
    sim.state.facilityRank = 2;
    ensureWarehouseWorkers();
    // Mark the normal save path dirty without prescribing or changing the current policy.
    sim.setPolicy(sim.state.policy);
  }

  function update(dt) {
    if (sim.state.facilityRank >= 2) return;

    const severity = sim.state.director?.severity ?? 0;
    if (severity <= 1) stableSeconds += Math.max(0, dt);
    else stableSeconds = 0;

    const rating = Math.max(sim.state.logisticsRating || 0, derivedRating());
    if (rating !== sim.state.logisticsRating) {
      sim.state.logisticsRating = rating;
      sim.setPolicy(sim.state.policy);
    }
    lastApplied = rating;
    promoteIfReady();
  }

  function snapshot() {
    return {
      rating: Math.max(sim.state.logisticsRating || 0, derivedRating()),
      shipped: shipmentScore(),
      throughput: throughputScore(),
      stability: stabilityScore(),
      contracts: contractScore(),
      stableSeconds,
      lastApplied,
    };
  }

  window.__logisticsBossFreedom = { snapshot };
  return { update, snapshot };
}
