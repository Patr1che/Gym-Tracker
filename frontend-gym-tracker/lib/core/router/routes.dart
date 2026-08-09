abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const onboarding = '/onboarding';

  static const home = '/home';

  static const workouts = '/workouts';
  static const exerciseLibrary = '/workouts/exercises';
  static String exerciseDetail(String id) => '/workouts/exercises/$id';
  static String programDetail(String id) => '/workouts/program/$id';
  static const newProgram = '/workouts/program-new';
  static String editProgram(String id) => '/workouts/program-edit/$id';
  static String copyProgram(String id) => '/workouts/program-copy/$id';

  static const progress = '/progress';
  static const measurements = '/progress/measurements';

  static const history = '/history';
  static String historyDetail(String id) => '/history/$id';

  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/profile/settings';
  static const backup = '/profile/settings/backup';
  static String settingsPage(String page) => '/profile/settings/$page';

  static const session = '/session';

  /// Exercise detail pushed *over* a running workout, so back returns to the
  /// session instead of the exercise library.
  static String sessionExercise(String id) => '/session/exercise/$id';

  static const authPaths = {login, register, forgotPassword};
}
