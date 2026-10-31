local Balance = {}

Balance.Stats = {
	PurityFloor = 0.70, SharpFloor = 0.30, DuraFloor = 0.50, ForgeFloor = 0.60,
	EdgeRef = 6.0, EdgeGain = 1.0,
	MassRef = 0.85, MassBias = 0.4, MassFactorMin = 0.6, MassFactorMax = 1.3,
	DamageBase = 25,
	BalanceIdeal = 0.08, BalanceTolerance = 0.04, BalanceFalloff = 0.30, BalanceReachMin = 1.0,
	StatMax = 100,
	Grid = { damage = 10, reach = 100, durability = 10, sharpness = 10, purity = 1000, balance = 10 },
}
Balance.Quality = {
	FailedStepCapTier = "Normal",
	QGrid = 10000,               -- Q and T quantized to 1e-4
	DifficultyGrid = 1000,       -- D_s stored to 1e-3 in the history
	WeightSumTolerance = 1e-9,
}

return Balance
