// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:masjid_app/examples/data/user_data.dart';
import 'package:flutter/material.dart';
import 'package:masjid_app/examples/styles/app_styles.dart';
import 'package:masjid_app/examples/utils/signout_dialog.dart';
import 'package:masjid_app/examples/utils/show_alert_dialog.dart';

class DrawerWidgets {
  Widget buildDrawer(BuildContext context) {
    // final displayName = UserData.getDisplayName();
    // final currUser = FirebaseAuth.instance.currentUser;
    // final userEmail = UserData.getUserEmail();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppStyles.backgroundColorGreen900,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: const Text(
                  'Hush kelibsiz!',
                  style: AppStyles.textStyleYellow,
                )),
            accountEmail: null,
            currentAccountPicture: CircleAvatar(
              child: ClipOval(
                child: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/4264/4264711.png',
                  fit: BoxFit.cover,
                  width: 90,
                  height: 90,
                ),
              ),
            ),
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
            decoration: BoxDecoration(
              color: AppStyles.backgroundColorGreen700,
              image: const DecorationImage(
                fit: BoxFit.fill,
                image: NetworkImage(
                    'https://mybayutcdn.bayut.com/mybayut/wp-content/uploads/Agency-Posts-Cover-B-01.jpg'),
              ),
            ),
          ),
          // ListTile(
          //   leading: const Icon(Icons.favorite),
          //   title: const Text('Favorites'),
          //   onTap: () {},
          // ),
          // ListTile(
          //   leading: const Icon(Icons.person),
          //   title: const Text('Friends'),
          //   onTap: () {},
          // ),
          // ListTile(
          //   leading: const Icon(Icons.share),
          //   title: const Text('Share'),
          //   onTap: () {},
          // ),
          // const ListTile(
          //   leading: Icon(Icons.notifications),
          //   title: Text('Request'),
          // ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Tizimga kirish'),
            onTap: () {
              Navigator.pushNamed(context, './login/')
                  .then((value) => Navigator.of(context).pop());
            },
          ),
          // const Divider(),
          // ListTile(
          //   leading: const Icon(Icons.settings),
          //   title: const Text('Settings'),
          //   onTap: () {},
          // ),
          // ListTile(
          //   leading: const Icon(Icons.description),
          //   title: const Text('Policies'),
          //   onTap: () {},
          // ),
          // const Divider(),
          ListTile(
            title: const Text('Tizimdan chiqish'),
            leading: const Icon(Icons.exit_to_app),
            onTap: () async {
              try {
                showSignOutConfirmationDialog(context);
              } catch (e) {
                showAlertDialog(context, 'Error', e);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text("Masjid qo'shish"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
