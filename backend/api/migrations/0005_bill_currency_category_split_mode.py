from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0004_bill_title_debt_friendgroup_notification'),
    ]

    operations = [
        migrations.AddField(
            model_name='bill',
            name='currency',
            field=models.CharField(blank=True, default='KGS', max_length=10),
        ),
        migrations.AddField(
            model_name='bill',
            name='category',
            field=models.CharField(blank=True, default='', max_length=50),
        ),
        migrations.AddField(
            model_name='bill',
            name='split_mode',
            field=models.CharField(blank=True, default='byItems', max_length=20),
        ),
    ]
