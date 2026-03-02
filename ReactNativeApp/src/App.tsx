/**
 * App.tsx — Root React Native component.
 *
 * Receives userId + locale as initialProperties from native.
 *
 * Bridge strategy (platform-specific):
 *   iOS    → TescoNativeBridge TurboModule → NotificationCenter → UIAlertController
 *   Android → BrownfieldMessaging.sendMessage → BridgeEvents SharedFlow → Compose badge
 */

import React from 'react';
import {
  Platform,
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { requireNativeModule } from 'expo-modules-core';
import { sendMessage } from 'expo-brownfield';

const TescoNativeBridge =
  Platform.OS === 'ios'
    ? requireNativeModule<{ onButtonTapped(message: string): Promise<void> }>(
        'TescoNativeBridge',
      )
    : null;

// Props injected by RCTRootViewFactory initialProperties
type Props = {
  userId?: string;
  locale?: string;
};

const TESCO_BLUE = '#00539F';

export default function App({ userId = 'unknown', locale = 'en' }: Props) {
  const [loading, setLoading] = React.useState(false);

  const handleCallNative = async () => {
    setLoading(true);
    try {
      if (Platform.OS === 'android') {
        sendMessage({ event: 'buttonTapped', userId });
      } else {
        await TescoNativeBridge!.onButtonTapped(`Hello from RN! userId=${userId}`);
      }
    } catch (e) {
      console.error('[Bridge] call failed:', e);
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>React Native Surface</Text>

      <View style={styles.card}>
        <Row label="userId" value={userId} />
        <Row label="locale" value={locale} />
      </View>

      <TouchableOpacity
        style={[styles.button, loading && styles.buttonDisabled]}
        onPress={handleCallNative}
        disabled={loading}
        activeOpacity={0.8}>
        {loading ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.buttonText}>Call Native</Text>
        )}
      </TouchableOpacity>

      <Text style={styles.hint}>
        {Platform.OS === 'android'
          ? 'Tap → BrownfieldMessaging → SharedFlow → Compose badge'
          : 'Tap → Expo Module → NotificationCenter → UIAlertController'}
      </Text>
    </View>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#F5F5F5',
    padding: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: TESCO_BLUE,
    marginBottom: 24,
  },
  card: {
    width: '100%',
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 32,
    shadowColor: '#000',
    shadowOpacity: 0.06,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 2,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 6,
  },
  rowLabel: { fontSize: 14, color: '#888' },
  rowValue: { fontSize: 14, fontWeight: '600', color: '#222' },
  button: {
    backgroundColor: TESCO_BLUE,
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 10,
    minWidth: 220,
    alignItems: 'center',
  },
  buttonDisabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  hint: {
    marginTop: 20,
    fontSize: 12,
    color: '#aaa',
    textAlign: 'center',
    lineHeight: 18,
  },
});
