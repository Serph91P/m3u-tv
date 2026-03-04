import React from 'react';
import { View, Text, Modal, TouchableOpacity, StyleSheet } from 'react-native';

interface Props {
  visible: boolean;
  position: number; // seconds
  duration?: number; // seconds
  onResume: () => void;
  onStartOver: () => void;
}

function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${m}:${String(s).padStart(2, '0')}`;
}

export default function ResumeDialog({ visible, position, duration, onResume, onStartOver }: Props) {
  const progressPercent =
    duration && duration > 0 ? Math.round((position / duration) * 100) : null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      statusBarTranslucent
    >
      <View style={styles.overlay}>
        <View style={styles.dialog}>
          <Text style={styles.title}>Resume Playback?</Text>
          <Text style={styles.subtitle}>
            {progressPercent !== null
              ? `You were ${progressPercent}% through (${formatTime(position)})`
              : `You were at ${formatTime(position)}`}
          </Text>

          <View style={styles.buttons}>
            <TouchableOpacity
              style={[styles.button, styles.resumeButton]}
              onPress={onResume}
              hasTVPreferredFocus
              activeOpacity={0.8}
            >
              <Text style={styles.resumeText}>Resume from {formatTime(position)}</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.button, styles.startOverButton]}
              onPress={onStartOver}
              activeOpacity={0.8}
            >
              <Text style={styles.startOverText}>Start from Beginning</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.75)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  dialog: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 32,
    width: 480,
    maxWidth: '80%',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  title: {
    color: '#fff',
    fontSize: 22,
    fontWeight: '700',
    marginBottom: 8,
  },
  subtitle: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 16,
    marginBottom: 28,
    textAlign: 'center',
  },
  buttons: {
    flexDirection: 'column',
    gap: 12,
    width: '100%',
  },
  button: {
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 8,
    alignItems: 'center',
  },
  resumeButton: {
    backgroundColor: '#6366f1',
  },
  startOverButton: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.3)',
  },
  resumeText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  startOverText: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 16,
  },
});
