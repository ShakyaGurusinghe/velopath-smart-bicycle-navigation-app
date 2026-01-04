class ConfidenceCalculator {
  static THRESHOLDS = {
    VERIFIED: 0.80,
    EXPIRED: 0.50,
    DELETED: 0.20
  };

  static SCORE_CHANGES = {
    ML_DETECTION: 0.15,
    USER_CONFIRM: 0.30,
    USER_DENY: -0.40
  };

  static DECAY_RATES = {
    pothole: 0.030,  // ~23 days to 50%
    bump: 0.008      // ~87 days to 50%
  };

  // Calculate current confidence with decay applied
  static getCurrentConfidence(hazard) {
    const daysSinceUpdate = this.getDaysSince(hazard.last_updated);
    const decayRate = hazard.decay_accelerated 
      ? parseFloat(hazard.decay_rate) * 2 
      : parseFloat(hazard.decay_rate);
    
    const currentScore = parseFloat(hazard.confidence_score);
    const decayedConfidence = currentScore * Math.exp(-decayRate * daysSinceUpdate);
    
    return Math.max(0, Math.min(1, decayedConfidence));
  }

  // Check if decay should accelerate (no confirmation for 7+ days)
  static shouldAccelerateDecay(hazard) {
    if (!hazard.last_confirmed) return false;
    const daysSinceConfirmation = this.getDaysSince(hazard.last_confirmed);
    return daysSinceConfirmation > 7;
  }

  // Update confidence after an event
  static updateConfidence(currentConfidence, eventType) {
    const change = this.SCORE_CHANGES[eventType] || 0;
    const newConfidence = parseFloat(currentConfidence) + change;
    return Math.max(0, Math.min(1, newConfidence));
  }

  // Determine status based on confidence
  static getStatus(confidence) {
    const score = parseFloat(confidence);
    if (score >= this.THRESHOLDS.VERIFIED) return 'verified';
    if (score >= this.THRESHOLDS.EXPIRED) return 'pending';
    return 'expired';
  }

  // Helper: calculate days since timestamp
  static getDaysSince(timestamp) {
    const then = new Date(timestamp);
    const now = new Date();
    return (now - then) / (1000 * 60 * 60 * 24);
  }
}

module.exports = ConfidenceCalculator;