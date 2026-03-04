import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  ActivityIndicator,
} from 'react-native';
import { useViewer } from '../context/ViewerContext';
import { colors } from '../theme';
import { RootStackScreenProps } from '../navigation/types';
import { scaledPixels } from '../hooks/useScale';
import { FocusablePressable } from '../components/FocusablePressable';
import { PlaylistViewer } from '../types/xtream';

export function ViewerSelectionScreen({ navigation }: RootStackScreenProps<'ViewerSelection'>) {
  const { viewers, activeViewer, setActiveViewer, createViewer, isLoading } = useViewer();
  const [showNewViewer, setShowNewViewer] = useState(false);
  const [newViewerName, setNewViewerName] = useState('');
  const [creating, setCreating] = useState(false);

  const handleSelectViewer = async (viewer: PlaylistViewer) => {
    await setActiveViewer(viewer);
    navigation.goBack();
  };

  const handleCreateViewer = async () => {
    const name = newViewerName.trim();
    if (!name) return;
    setCreating(true);
    await createViewer(name);
    setCreating(false);
    setShowNewViewer(false);
    setNewViewerName('');
  };

  return (
    <View style={styles.container}>
      <View style={styles.dialog}>
        <Text style={styles.title}>Select Viewer</Text>
        <Text style={styles.subtitle}>Choose who is watching</Text>

        <ScrollView style={styles.list} contentContainerStyle={styles.listContent}>
          {isLoading ? (
            <ActivityIndicator color={colors.primary} size="large" />
          ) : (
            viewers.map((viewer, index) => {
              const isActive = activeViewer?.ulid === viewer.ulid;
              return (
                <FocusablePressable
                  key={viewer.ulid}
                  preferredFocus={isActive || index === 0}
                  onSelect={() => handleSelectViewer(viewer)}
                  style={({ isFocused }) => [
                    styles.viewerItem,
                    isActive && styles.viewerItemActive,
                    isFocused && styles.viewerItemFocused,
                  ]}
                >
                  {({ isFocused }) => (
                    <View style={styles.viewerRow}>
                      <View style={[styles.avatar, isActive && styles.avatarActive]}>
                        <Text style={styles.avatarText}>{viewer.name.charAt(0).toUpperCase()}</Text>
                      </View>
                      <View style={styles.viewerInfo}>
                        <Text style={[styles.viewerName, (isActive || isFocused) && styles.viewerNameActive]}>
                          {viewer.name}
                        </Text>
                        {viewer.is_admin && (
                          <Text style={styles.adminBadge}>Admin</Text>
                        )}
                      </View>
                      {isActive && <Text style={styles.checkmark}>✓</Text>}
                    </View>
                  )}
                </FocusablePressable>
              );
            })
          )}

          {showNewViewer ? (
            <View style={styles.newViewerForm}>
              <TextInput
                style={styles.input}
                value={newViewerName}
                onChangeText={setNewViewerName}
                placeholder="Viewer name"
                placeholderTextColor={colors.textSecondary}
                autoFocus
                autoCapitalize="words"
                autoCorrect={false}
                onSubmitEditing={handleCreateViewer}
              />
              <View style={styles.formButtons}>
                <FocusablePressable
                  style={({ isFocused }) => [styles.formButton, styles.cancelButton, isFocused && styles.viewerItemFocused]}
                  onSelect={() => { setShowNewViewer(false); setNewViewerName(''); }}
                >
                  {() => <Text style={styles.cancelText}>Cancel</Text>}
                </FocusablePressable>
                <FocusablePressable
                  style={({ isFocused }) => [styles.formButton, styles.createButton, isFocused && styles.createButtonFocused]}
                  onSelect={handleCreateViewer}
                >
                  {() => creating
                    ? <ActivityIndicator color="#fff" size="small" />
                    : <Text style={styles.createText}>Create</Text>
                  }
                </FocusablePressable>
              </View>
            </View>
          ) : (
            <FocusablePressable
              style={({ isFocused }) => [styles.viewerItem, styles.addButton, isFocused && styles.viewerItemFocused]}
              onSelect={() => setShowNewViewer(true)}
            >
              {({ isFocused }) => (
                <View style={styles.viewerRow}>
                  <View style={[styles.avatar, styles.addAvatar]}>
                    <Text style={styles.avatarText}>+</Text>
                  </View>
                  <Text style={[styles.viewerName, isFocused && styles.viewerNameActive]}>Add Viewer</Text>
                </View>
              )}
            </FocusablePressable>
          )}
        </ScrollView>

        <FocusablePressable
          style={({ isFocused }) => [styles.closeButton, isFocused && styles.closeButtonFocused]}
          onSelect={() => navigation.goBack()}
        >
          {({ isFocused }) => (
            <Text style={[styles.closeText, isFocused && styles.closeTextFocused]}>Close</Text>
          )}
        </FocusablePressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.8)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  dialog: {
    backgroundColor: '#1a1a2e',
    borderRadius: scaledPixels(16),
    padding: scaledPixels(40),
    width: scaledPixels(600),
    maxWidth: '80%',
    maxHeight: '80%',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  title: {
    color: colors.text,
    fontSize: scaledPixels(32),
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: scaledPixels(8),
  },
  subtitle: {
    color: colors.textSecondary,
    fontSize: scaledPixels(18),
    textAlign: 'center',
    marginBottom: scaledPixels(30),
  },
  list: {
    maxHeight: scaledPixels(500),
  },
  listContent: {
    gap: scaledPixels(10),
  },
  viewerItem: {
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: scaledPixels(12),
    padding: scaledPixels(20),
    borderWidth: 2,
    borderColor: 'transparent',
  },
  viewerItemActive: {
    backgroundColor: 'rgba(236,0,63,0.15)',
    borderColor: colors.primary,
  },
  viewerItemFocused: {
    borderColor: colors.primary,
    backgroundColor: 'rgba(255,255,255,0.1)',
  },
  viewerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: scaledPixels(16),
  },
  avatar: {
    width: scaledPixels(48),
    height: scaledPixels(48),
    borderRadius: scaledPixels(24),
    backgroundColor: 'rgba(255,255,255,0.15)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarActive: {
    backgroundColor: colors.primary,
  },
  addAvatar: {
    backgroundColor: 'rgba(255,255,255,0.1)',
  },
  avatarText: {
    color: colors.text,
    fontSize: scaledPixels(22),
    fontWeight: 'bold',
  },
  viewerInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: scaledPixels(12),
  },
  viewerName: {
    color: colors.textSecondary,
    fontSize: scaledPixels(22),
  },
  viewerNameActive: {
    color: colors.text,
    fontWeight: 'bold',
  },
  adminBadge: {
    color: colors.primary,
    fontSize: scaledPixels(14),
    backgroundColor: 'rgba(236,0,63,0.2)',
    paddingHorizontal: scaledPixels(8),
    paddingVertical: scaledPixels(2),
    borderRadius: scaledPixels(4),
  },
  checkmark: {
    color: colors.primary,
    fontSize: scaledPixels(24),
    fontWeight: 'bold',
  },
  addButton: {
    borderStyle: 'dashed',
    borderColor: 'rgba(255,255,255,0.2)',
    borderWidth: 2,
  },
  newViewerForm: {
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: scaledPixels(12),
    padding: scaledPixels(20),
    gap: scaledPixels(12),
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: scaledPixels(8),
    padding: scaledPixels(14),
    color: colors.text,
    fontSize: scaledPixels(20),
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  formButtons: {
    flexDirection: 'row',
    gap: scaledPixels(12),
  },
  formButton: {
    flex: 1,
    paddingVertical: scaledPixels(14),
    borderRadius: scaledPixels(8),
    alignItems: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  cancelButton: {
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  createButton: {
    backgroundColor: colors.primary,
  },
  createButtonFocused: {
    borderColor: colors.text,
    transform: [{ scale: 1.03 }],
  },
  cancelText: {
    color: colors.textSecondary,
    fontSize: scaledPixels(18),
  },
  createText: {
    color: colors.text,
    fontSize: scaledPixels(18),
    fontWeight: 'bold',
  },
  closeButton: {
    marginTop: scaledPixels(24),
    paddingVertical: scaledPixels(16),
    borderRadius: scaledPixels(10),
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  closeButtonFocused: {
    borderColor: colors.text,
    backgroundColor: 'rgba(255,255,255,0.1)',
  },
  closeText: {
    color: colors.textSecondary,
    fontSize: scaledPixels(20),
  },
  closeTextFocused: {
    color: colors.text,
  },
});
