import React from 'react';
import { View, Text, StyleSheet, Button } from 'react-native';
import auth from '@react-native-firebase/auth';

const HomeScreen = () => {
  const handleSignOut = async () => {
    try {
      await auth().signOut();
      // Navigate back to AuthScreen or handle as appropriate
      console.log('User signed out!');
    } catch (error) {
      console.error('Sign out error', error);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Welcome to SplitSmart!</Text>
      <Text>You are logged in.</Text>
      <Button title="Sign Out" onPress={handleSignOut} />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
});

export default HomeScreen;
