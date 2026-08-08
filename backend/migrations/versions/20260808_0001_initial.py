"""initial

Revision ID: 20260808_0001
Revises: 
Create Date: 2026-08-08 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260808_0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'user',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('email', sa.String(length=180), nullable=False),
        sa.Column('name', sa.String(length=80), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=False),
        sa.Column('consent_version', sa.String(length=20), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint('email', name='uq_user_email'),
    )
    op.create_table(
        'report',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('owner_id', sa.Integer(), sa.ForeignKey('user.id'), nullable=True),
        sa.Column('name', sa.String(length=80), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False),
        sa.Column('place', sa.String(length=180), nullable=False),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('event_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('color', sa.String(length=80), nullable=True),
        sa.Column('sex', sa.String(length=20), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('image_url', sa.String(length=500), nullable=True),
        sa.Column('public_contact', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        'sighting',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('report_id', sa.String(length=36), sa.ForeignKey('report.id'), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('place', sa.String(length=180), nullable=True),
        sa.Column('contact', sa.String(length=180), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        'notification_preference',
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('user.id'), primary_key=True),
        sa.Column('in_app', sa.Boolean(), nullable=False),
        sa.Column('email_sightings', sa.Boolean(), nullable=False),
        sa.Column('email_status', sa.Boolean(), nullable=False),
        sa.Column('email_reminders', sa.Boolean(), nullable=False),
    )
    op.create_table(
        'notification',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('user.id'), nullable=False),
        sa.Column('kind', sa.String(length=40), nullable=False),
        sa.Column('title', sa.String(length=180), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('report_id', sa.String(length=36), sa.ForeignKey('report.id'), nullable=True),
        sa.Column('read_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(op.f('ix_notification_created_at'), 'notification', ['created_at'], unique=False)
    op.create_index(op.f('ix_notification_user_id'), 'notification', ['user_id'], unique=False)
    op.create_table(
        'email_delivery',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('user.id'), nullable=False),
        sa.Column('kind', sa.String(length=40), nullable=False),
        sa.Column('status', sa.String(length=30), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    )


def downgrade():
    op.drop_table('email_delivery')
    op.drop_index(op.f('ix_notification_user_id'), table_name='notification')
    op.drop_index(op.f('ix_notification_created_at'), table_name='notification')
    op.drop_table('notification')
    op.drop_table('notification_preference')
    op.drop_table('sighting')
    op.drop_table('report')
    op.drop_table('user')
