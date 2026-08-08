final List<Map<String, dynamic>> programSeeds = [
  {
    'id': 'prog_beginner_full_body',
    'name': 'Beginner Full Body',
    'description': 'A simple three-day routine that trains the whole body each session. '
        'Perfect for building foundational strength and learning the core movement patterns.',
    'difficulty': 'beginner',
    'daysPerWeek': 3,
    'estimatedDurationMin': 45,
    'days': [
      {
        'id': 'bfb_day1',
        'name': 'Day 1 · Full Body A',
        'exercises': [
          {'exerciseId': 'ex_chest_press', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_lat_pulldown', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_shoulder_press', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_leg_press', 'sets': 3, 'repsText': '10-12', 'restSeconds': 120},
          {'exerciseId': 'ex_plank', 'sets': 3, 'repsText': '30-60 sec', 'restSeconds': 60},
        ],
      },
      {
        'id': 'bfb_day2',
        'name': 'Day 2 · Full Body B',
        'exercises': [
          {'exerciseId': 'ex_goblet_squat', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_seated_row', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_push_up', 'sets': 3, 'repsText': '8-15', 'restSeconds': 60},
          {'exerciseId': 'ex_leg_curl', 'sets': 3, 'repsText': '12-15', 'restSeconds': 60},
          {'exerciseId': 'ex_crunch', 'sets': 3, 'repsText': '15-20', 'restSeconds': 45},
        ],
      },
      {
        'id': 'bfb_day3',
        'name': 'Day 3 · Full Body C',
        'exercises': [
          {'exerciseId': 'ex_romanian_deadlift', 'sets': 3, 'repsText': '10-12', 'restSeconds': 120},
          {'exerciseId': 'ex_chest_fly', 'sets': 3, 'repsText': '12-15', 'restSeconds': 60},
          {'exerciseId': 'ex_lateral_raise', 'sets': 3, 'repsText': '12-15', 'restSeconds': 60},
          {'exerciseId': 'ex_lunge', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_leg_raise', 'sets': 3, 'repsText': '10-15', 'restSeconds': 60},
        ],
      },
    ],
  },
  {
    'id': 'prog_ppl',
    'name': 'Push Pull Legs',
    'description': 'The classic push, pull, and legs split built around heavy compound lifts. '
        'A proven structure for building muscle and strength three days per week.',
    'difficulty': 'intermediate',
    'daysPerWeek': 3,
    'estimatedDurationMin': 60,
    'days': [
      {
        'id': 'ppl_push',
        'name': 'Push',
        'exercises': [
          {'exerciseId': 'ex_bench_press', 'sets': 4, 'repsText': '6-10', 'restSeconds': 150},
          {'exerciseId': 'ex_incline_db_press', 'sets': 3, 'repsText': '8-12', 'restSeconds': 90},
          {'exerciseId': 'ex_shoulder_press', 'sets': 3, 'repsText': '8-12', 'restSeconds': 120},
          {'exerciseId': 'ex_lateral_raise', 'sets': 3, 'repsText': '12-15', 'restSeconds': 60},
          {'exerciseId': 'ex_triceps_pushdown', 'sets': 3, 'repsText': '10-15', 'restSeconds': 60},
        ],
      },
      {
        'id': 'ppl_pull',
        'name': 'Pull',
        'exercises': [
          {'exerciseId': 'ex_deadlift', 'sets': 4, 'repsText': '5-8', 'restSeconds': 180},
          {'exerciseId': 'ex_lat_pulldown', 'sets': 3, 'repsText': '8-12', 'restSeconds': 90},
          {'exerciseId': 'ex_seated_row', 'sets': 3, 'repsText': '8-12', 'restSeconds': 90},
          {'exerciseId': 'ex_face_pull', 'sets': 3, 'repsText': '12-20', 'restSeconds': 60},
          {'exerciseId': 'ex_hammer_curl', 'sets': 3, 'repsText': '10-15', 'restSeconds': 60},
        ],
      },
      {
        'id': 'ppl_legs',
        'name': 'Legs',
        'exercises': [
          {'exerciseId': 'ex_squat', 'sets': 4, 'repsText': '6-10', 'restSeconds': 180},
          {'exerciseId': 'ex_romanian_deadlift', 'sets': 3, 'repsText': '8-12', 'restSeconds': 120},
          {'exerciseId': 'ex_leg_press', 'sets': 3, 'repsText': '10-12', 'restSeconds': 120},
          {'exerciseId': 'ex_calf_raise', 'sets': 4, 'repsText': '12-20', 'restSeconds': 60},
          {'exerciseId': 'ex_leg_curl', 'sets': 3, 'repsText': '10-15', 'restSeconds': 60},
        ],
      },
    ],
  },
  {
    'id': 'prog_upper_lower',
    'name': 'Upper Lower Split',
    'description': 'A four-day split alternating upper and lower body sessions for balanced development. '
        'Ideal for lifters ready to add training volume and frequency beyond a full-body routine.',
    'difficulty': 'intermediate',
    'daysPerWeek': 4,
    'estimatedDurationMin': 60,
    'days': [
      {
        'id': 'ul_upper_a',
        'name': 'Upper A',
        'exercises': [
          {'exerciseId': 'ex_bench_press', 'sets': 4, 'repsText': '6-10', 'restSeconds': 150},
          {'exerciseId': 'ex_bent_over_row', 'sets': 4, 'repsText': '6-10', 'restSeconds': 150},
          {'exerciseId': 'ex_shoulder_press', 'sets': 3, 'repsText': '8-12', 'restSeconds': 120},
          {'exerciseId': 'ex_barbell_curl', 'sets': 3, 'repsText': '10-12', 'restSeconds': 60},
          {'exerciseId': 'ex_skull_crusher', 'sets': 3, 'repsText': '10-12', 'restSeconds': 60},
        ],
      },
      {
        'id': 'ul_lower_a',
        'name': 'Lower A',
        'exercises': [
          {'exerciseId': 'ex_squat', 'sets': 4, 'repsText': '6-10', 'restSeconds': 180},
          {'exerciseId': 'ex_romanian_deadlift', 'sets': 3, 'repsText': '8-12', 'restSeconds': 120},
          {'exerciseId': 'ex_leg_extension', 'sets': 3, 'repsText': '12-15', 'restSeconds': 60},
          {'exerciseId': 'ex_calf_raise', 'sets': 4, 'repsText': '12-20', 'restSeconds': 60},
          {'exerciseId': 'ex_plank', 'sets': 3, 'repsText': '30-60 sec', 'restSeconds': 60},
        ],
      },
      {
        'id': 'ul_upper_b',
        'name': 'Upper B',
        'exercises': [
          {'exerciseId': 'ex_incline_db_press', 'sets': 4, 'repsText': '8-12', 'restSeconds': 120},
          {'exerciseId': 'ex_pull_up', 'sets': 4, 'repsText': '6-10', 'restSeconds': 120},
          {'exerciseId': 'ex_arnold_press', 'sets': 3, 'repsText': '8-12', 'restSeconds': 90},
          {'exerciseId': 'ex_preacher_curl', 'sets': 3, 'repsText': '10-12', 'restSeconds': 60},
          {'exerciseId': 'ex_close_grip_bench', 'sets': 3, 'repsText': '8-12', 'restSeconds': 90},
        ],
      },
      {
        'id': 'ul_lower_b',
        'name': 'Lower B',
        'exercises': [
          {'exerciseId': 'ex_leg_press', 'sets': 4, 'repsText': '10-12', 'restSeconds': 120},
          {'exerciseId': 'ex_hip_thrust', 'sets': 4, 'repsText': '8-12', 'restSeconds': 120},
          {'exerciseId': 'ex_leg_curl', 'sets': 3, 'repsText': '10-15', 'restSeconds': 60},
          {'exerciseId': 'ex_lunge', 'sets': 3, 'repsText': '10-12', 'restSeconds': 90},
          {'exerciseId': 'ex_leg_raise', 'sets': 3, 'repsText': '10-15', 'restSeconds': 60},
        ],
      },
    ],
  },
];
